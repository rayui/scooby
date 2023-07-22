MASTER_HOSTNAME=buffy

LOOP_DEV=/dev/loop0

BOOT_MNT=/tmp/boot
ROOT_MNT=/tmp/root

AGENTCONFIGBASE=/etc/scooby/agents
AGENTINSTANCEBASE=/var/lib/scooby/agents
AGENTMOUNTBASE=/mnt/scooby/agents
BASEPATH=/var/lib/scooby/base

AGENTCONFIGPATH=${ROOT_MNT}${AGENTCONFIGBASE}
AGENTINSTANCEPATH=${ROOT_MNT}${AGENTINSTANCEBASE}
AGENTMOUNTPATH=${ROOT_MNT}${AGENTMOUNTBASE}
CLOUDCONFIGWWWPATH=${ROOT_MNT}/var/www/html/cloud-config

OVERLAYWORKPATH=/var/lib/scooby/overlay
RANCHERSTORAGEPATH=/var/lib/rancher

VAGRANT=/vagrant
IMGPATH=${VAGRANT}/images/scooby.img
SERVERCONFIGPATH=${VAGRANT}/server

#MOUNT IMAGE AS LOOP DEVICE
losetup -Pf ${IMGPATH}
mkdir -p ${BOOT_MNT}
mkdir -p ${ROOT_MNT}
mount ${LOOP_DEV}p1 ${BOOT_MNT}
mount ${LOOP_DEV}p2 ${ROOT_MNT}

### SET UP SERVER BOOT CONFIG
cat - > ${BOOT_MNT}/network-config << EOF
version: 2
ethernets:
  ${LC_EXTERNAL_DEVICE}:
    dhcp4: false
    addresses:
    - ${LC_EXTERNAL_IP}/${LC_EXTERNAL_NM}
    gateway4: ${LC_EXTERNAL_GW}
    nameservers:
      search: [${LC_EXTERNAL_DOMAIN}]
      addresses: [${LC_EXTERNAL_DNS}, ${LC_LOCAL_DNS}]
  ${LC_INTERNAL_DEVICE}:
    dhcp4: false
    gateway4: ${LC_EXTERNAL_IP}
    addresses:
    - ${LC_INTERNAL_IP}/${LC_INTERNAL_NM}
    nameservers:
      search: [${LC_INTERNAL_DOMAIN}]
      addresses: [${LC_EXTERNAL_DNS}, ${LC_LOCAL_DNS}]
EOF
chmod a+x ${BOOT_MNT}/network-config

cat - > ${BOOT_MNT}/meta-data << EOF
network:
  version: 2
  ethernets:
    ${LC_EXTERNAL_DEVICE}:
      dhcp4: false
      addresses:
      - ${LC_EXTERNAL_IP}/${LC_EXTERNAL_NM}
      gateway4: ${LC_EXTERNAL_GW}
      nameservers:
        search: [${LC_EXTERNAL_DOMAIN}]
        addresses: [${LC_EXTERNAL_DNS}, ${LC_LOCAL_DNS}]
    ${LC_INTERNAL_DEVICE}:
      dhcp4: false
      gateway4: ${LC_EXTERNAL_IP}
      addresses:
      - ${LC_INTERNAL_IP}/${LC_INTERNAL_NM}
      nameservers:
        search: [${LC_INTERNAL_DOMAIN}]
        addresses: [${LC_EXTERNAL_DNS}, ${LC_LOCAL_DNS}]
EOF
chmod a+x ${BOOT_MNT}/meta-data

cat - > ${BOOT_MNT}/user-data << EOF
#cloud-config
# vim: syntax=yaml
hostname: ${MASTER_HOSTNAME}
manage_etc_hosts: false
packages:
  - vim
  - libarchive-tools
  - git
  - curl
  - unzip
  - rsync
  - dnsmasq
  - bind9-utils
  - dnsutils
  - iptables
  - iptables-persistent
  - nfs-server
  - lighttpd
  - cloud-init
users:
  - default
bootcmd:
  - mkdir -p /var/lib/minecraft-data/
runcmd:
  - sh /usr/local/bin/finalize-cloud-init.sh
EOF
chmod a+x ${BOOT_MNT}/user-data

### COPY STATIC CONFIG
rsync -x --progress -r ${SERVERCONFIGPATH}/* ${ROOT_MNT}
echo "COPIED STATIC CONFIG"

### BASE SERVICES CONFIG
## INTERNAL DNSMASQ
DHCP_RANGE=$(echo ${LC_INTERNAL_IP} | grep -Eo '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}')
cat - > ${ROOT_MNT}/etc/dnsmasq.conf << EOF
port=0
domain=${LC_INTERNAL_DOMAIN}

interface=${LC_INTERNAL_DEVICE}
bind-interfaces
dhcp-authoritative

expand-hosts
log-dhcp
#dhcp-ignore=tag:!known

dhcp-range=tag:${LC_INTERNAL_DEVICE},${DHCP_RANGE}192,${DHCP_RANGE}254
dhcp-option=tag:${LC_INTERNAL_DEVICE},66,${LC_INTERNAL_IP}
dhcp-option=tag:${LC_INTERNAL_DEVICE},option:router,${LC_INTERNAL_IP}
dhcp-option=tag:${LC_INTERNAL_DEVICE},6,${LC_EXTERNAL_DNS}

enable-tftp
tftp-root=/tftpboot/
pxe-service=0,"Raspberry Pi Boot"
EOF

## ALLOW AGENTS INTERNET ACCESS
mkdir -p ${ROOT_MNT}/etc/iptables
cat - > ${ROOT_MNT}/etc/iptables/rules.v4 << EOF
*filter
:INPUT ACCEPT
:FORWARD ACCEPT
:OUTPUT ACCEPT
-A FORWARD -i ${LC_EXTERNAL_DEVICE} -o ${LC_INTERNAL_DEVICE} -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i ${LC_INTERNAL_DEVICE} -o ${LC_EXTERNAL_DEVICE} -j ACCEPT
COMMIT
*nat
:PREROUTING ACCEPT
:INPUT ACCEPT
:OUTPUT ACCEPT
:POSTROUTING ACCEPT
-A POSTROUTING -o ${LC_EXTERNAL_DEVICE} -j MASQUERADE
COMMIT
EOF

## INTERNAL LIGHTTPD FOR SERVING CLOUD_INIT
mkdir -p ${ROOT_MNT}/etc/lighttpd
cat - > ${ROOT_MNT}/etc/lighttpd/lighttpd.conf << EOF
server.bind 		= "${LC_INTERNAL_IP}"
server.port 		= 58087
server.document-root        = "/var/www/html"
server.upload-dirs          = ( "/var/cache/lighttpd/uploads" )
server.errorlog             = "/var/log/lighttpd/error.log"
server.pid-file             = "/run/lighttpd.pid"
server.username             = "www-data"
server.groupname            = "www-data"
EOF

## K3S CONFIG
mkdir -p ${ROOT_MNT}/etc/rancher/k3s
cat - > ${ROOT_MNT}/etc/rancher/k3s/config.yaml << EOF
kube-controller-manager-arg:
- "bind-address=${LC_INTERNAL_IP}"
kube-proxy-arg:
- "metrics-bind-address=${LC_INTERNAL_IP}"
kube-scheduler-arg:
- "bind-address=${LC_INTERNAL_IP}"
# Controller Manager exposes etcd sqllite metrics
etcd-expose-metrics: true
EOF

## EXTERNAL AVAHI
mkdir -p ${ROOT_MNT}/etc/avahi/
cat - > ${ROOT_MNT}/etc/avahi/avahi-daemon.conf << EOF
[server]
use-ipv4=yes
use-ipv6=yes
#only allow on public interface
allow-interfaces=${LC_EXTERNAL_DEVICE}
ratelimit-interval-usec=1000000
ratelimit-burst=1000

[wide-area]
enable-wide-area=yes

[publish]
publish-hinfo=no
publish-workstation=no
EOF

### ENV
mkdir -p ${ROOT_MNT}/etc/scooby
cat - > ${ROOT_MNT}/etc/scooby/.env << EOF
  LC_EXTERNAL_IP=${LC_EXTERNAL_IP}
  LC_INTERNAL_IP=${LC_INTERNAL_IP}
  LC_INTERNAL_DEVICE=${LC_INTERNAL_DEVICE}
  LC_DEFAULT_USER=${LC_DEFAULT_USER}
  LC_AGENT_IMAGE_HREF="${LC_AGENT_IMAGE_HREF}"
EOF
echo "CREATED ENV FILE"

### HOSTS
cat - >> ${ROOT_MNT}/etc/hosts << EOF
  ${LC_INTERNAL_IP} ${MASTER_HOSTNAME}
EOF

#CREATE TFTPBOOT DIRECTORY

mkdir -p ${ROOT_MNT}/tftpboot
echo "CREATED TFTP ROOT"

#CREATE AGENT BASE IMAGE FOR MOUNT
mkdir -p ${ROOT_MNT}${BASEPATH}/boot

### AGENT CONFIG
mkdir -p ${AGENTCONFIGPATH}
AGENTS=$(find ${AGENTCONFIGPATH}/* -maxdepth 0 -type d -printf "%f\n")
FSID=1

####################
### AGENT LOOP START
####################

for AGENT in ${AGENTS}
do

echo "CONFIGURING AGENT ${AGENT}"
### AGENT NFS MOUNTS
mkdir -p ${ROOT_MNT}/var/lib/scooby/agents/${AGENT}
mkdir -p ${ROOT_MNT}/mnt/scooby/agents/${AGENT}

### AGENT HOST ENTRY
AGENT_IP=$(cat ${AGENTCONFIGPATH}/${AGENT}/ip)
cat - >> ${ROOT_MNT}/etc/hosts << EOF
${AGENT_IP} ${AGENT}
EOF

### FSTAB ENTRY
mkdir -p ${ROOT_MNT}${OVERLAYWORKPATH}/${AGENT}
cat - >> ${ROOT_MNT}/etc/fstab << EOF
${AGENT} ${AGENTMOUNTBASE}/${AGENT} overlay nfs_export=on,index=on,defaults,lowerdir=${AGENTCONFIGBASE}/${AGENT}:${BASEPATH},upperdir=${AGENTINSTANCEBASE}/${AGENT},workdir=${OVERLAYWORKPATH}/${AGENT} 0 0
EOF

### EXPORT THE AGENT FS
cat - >> ${ROOT_MNT}/etc/exports << EOF
${AGENTMOUNTBASE}/${AGENT} ${AGENT}(rw,sync,no_subtree_check,no_root_squash,fsid=${FSID})
EOF

### SETUP AGENT TFTPBOOT
ln -s /mnt/scooby/agents/${AGENT}/boot ${ROOT_MNT}/tftpboot/$(cat ${AGENTCONFIGPATH}/${AGENT}/tftp_client_id)

### CREATE AGENT NETWORK BOOT FILES
mkdir -p ${AGENTCONFIGPATH}/${AGENT}/boot/

### CREATE AGENT CMDLINE.TXT
cat - > ${AGENTCONFIGPATH}/${AGENT}/boot/cmdline.txt << EOF
dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 ip=dhcp root=/dev/nfs nfsroot=${LC_INTERNAL_IP}:/mnt/scooby/agents/${AGENT},tcp,vers=3 rw elevator=deadline rootwait ds=nocloud-net;s=http://${LC_INTERNAL_IP}:58087/cloud-config/${AGENT}/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
EOF
chmod a+x ${AGENTCONFIGPATH}/${AGENT}/boot/cmdline.txt

### CREATE AGENT USER-DATA
cat - > ${AGENTCONFIGPATH}/${AGENT}/boot/user-data << EOF
#cloud-config
# vim: syntax=yaml
hostname: ${AGENT}
manage_etc_hosts: true
package_update: false
package_upgrade: false
package_reboot_if_required: true
users:
  - default
runcmd:
  - sh /usr/local/bin/finalize-cloud-init-agent.sh
EOF
chmod a+x ${AGENTCONFIGPATH}/${AGENT}/boot/user-data

### CREATE AGENT META-DATA
cat - > ${AGENTCONFIGPATH}/${AGENT}/boot/meta-data << EOF
network:
  version: 2
  ethernets:
    ${LC_EXTERNAL_DEVICE}:
      dhcp4: true
EOF
chmod a+x ${AGENTCONFIGPATH}/${AGENT}/boot/meta-data  

### LINK AGENT CLOUD BOOT CONFIG
mkdir -p ${CLOUDCONFIGWWWPATH}/${AGENT}
ln -s ${AGENTCONFIGBASE}/${AGENT}/boot/user-data ${CLOUDCONFIGWWWPATH}/${AGENT}
ln -s ${AGENTCONFIGBASE}/${AGENT}/boot/meta-data ${CLOUDCONFIGWWWPATH}/${AGENT}

### Local mount point for rancher see here: https://github.com/containerd/containerd/issues/5464
mkdir -p ${AGENTCONFIGPATH}/${AGENT}${RANCHERSTORAGEPATH}

### CREATE AGENT FSTAB
mkdir -p ${AGENTCONFIGPATH}/${AGENT}/etc/
AGENT_RANCHER_PART_UUID=$(cat ${AGENTCONFIGPATH}/${AGENT}/rancher_partition_uuid)

cat - > ${AGENTCONFIGPATH}/${AGENT}/etc/fstab << EOF
proc /proc proc defaults 0 0
${LC_INTERNAL_IP}:${AGENTMOUNTBASE}/${AGENT} / nfs defaults 0 0
UUID="${AGENT_RANCHER_PART_UUID}" ${RANCHERSTORAGEPATH} ext4 defaults 0 0
EOF

### CREATE ENV
mkdir -p ${AGENTCONFIGPATH}/${AGENT}/etc/scooby
cat - > ${AGENTCONFIGPATH}/${AGENT}/etc/scooby/.env << EOF
LC_INTERNAL_IP=${LC_INTERNAL_IP}
LC_DEFAULT_USER=${LC_DEFAULT_USER}
EOF

### CREATE AGENT DNSMASQ ENTRY
AGENT_ETHERNET=$(cat ${AGENTCONFIGPATH}/${AGENT}/ethernet)
AGENT_IP=$(cat ${AGENTCONFIGPATH}/${AGENT}/ip)
cat - >> ${ROOT_MNT}/etc/dnsmasq.conf << EOF
dhcp-host=net:${AGENT},${AGENT_ETHERNET},${AGENT},${AGENT_IP},24h
dhcp-option=net:${AGENT},17,${LC_INTERNAL_IP}:${AGENTMOUNTBASE}/${AGENT}
EOF

### COPY BINARIES
mkdir -p ${AGENTCONFIGPATH}/${AGENT}/usr/local/bin
rsync -xa --progress -r ${SERVERCONFIGPATH}/usr/local/bin/finalize-cloud-init-agent.sh ${AGENTCONFIGPATH}/${AGENT}/usr/local/bin/
chmod a+x ${AGENTCONFIGPATH}/${AGENT}/usr/local/bin/finalize-cloud-init-agent.sh

FSID=$((FSID+1))

done

###################
### AGENT LOOP END
###################

echo "AGENTS CONFIGURED"

umount ${ROOT_MNT}
umount ${BOOT_MNT}