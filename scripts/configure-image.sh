MASTER_HOSTNAME=buffy

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
mount /dev/loop0p1 ${BOOT_MNT}
mount /dev/loop0p2 ${ROOT_MNT}

### COPY SERVER FILES
rsync -x --progress -r ${SERVERCONFIGPATH}/* ${ROOT_MNT}
echo "COPIED SERVER FILES"

### GENERATE BOOT FILES
printf "version: 2
ethernets:
  eth0:
    dhcp4: false
    addresses:
    - ${LC_EXTERNAL_IP}/${LC_EXTERNAL_NM}
    gateway4: ${LC_EXTERNAL_GW}
    nameservers:
      search: [${LC_EXTERNAL_DOMAIN}]
      addresses: [${LC_EXTERNAL_DNS}, ${LC_LOCAL_DNS}]
  eth1:
    dhcp4: false
    gateway4: ${LC_EXTERNAL_IP}
    addresses:
    - ${LC_INTERNAL_IP}/${LC_INTERNAL_NM}
    nameservers:
      search: [${LC_INTERNAL_DOMAIN}]
      addresses: [${LC_EXTERNAL_DNS}, ${LC_LOCAL_DNS}]" > ${BOOT_MNT}/network-config
chmod a+x ${BOOT_MNT}/network-config

printf "network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses:
      - ${LC_EXTERNAL_IP}/${LC_EXTERNAL_NM}
      gateway4: ${LC_EXTERNAL_GW}
      nameservers:
        search: [${LC_EXTERNAL_DOMAIN}]
        addresses: [${LC_EXTERNAL_DNS}, ${LC_LOCAL_DNS}]
    eth1:
      dhcp4: false
      gateway4: ${LC_EXTERNAL_IP}
      addresses:
      - ${LC_INTERNAL_IP}/${LC_INTERNAL_NM}
      nameservers:
        search: [${LC_INTERNAL_DOMAIN}]
        addresses: [${LC_EXTERNAL_DNS}, ${LC_LOCAL_DNS}]" > ${BOOT_MNT}/meta-data
chmod a+x ${BOOT_MNT}/meta-data

printf "#cloud-config
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
  - sh /usr/local/bin/finalize-cloud-init.sh" > ${BOOT_MNT}/user-data
chmod a+x ${BOOT_MNT}/user-data

### BASE SERVICES CONFIG
## INTERNAL DNSMASQ

DHCP_RANGE=$(echo ${LC_INTERNAL_IP} | grep -Eo '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}')
printf "port=0
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
pxe-service=0,\"Raspberry Pi Boot\"\n" > ${ROOT_MNT}/etc/dnsmasq.conf

## ALLOW AGENTS INTERNET ACCESS
mkdir -p ${ROOT_MNT}/etc/iptables
printf "*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A FORWARD -i ${LC_EXTERNAL_DEVICE} -o ${LC_INTERNAL_DEVICE} -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i ${LC_INTERNAL_DEVICE} -o ${LC_EXTERNAL_DEVICE} -j ACCEPT
COMMIT
*nat
:PREROUTING ACCEPT [95416:7110036]
:INPUT ACCEPT [94707:7084699]
:OUTPUT ACCEPT [96642:5810991]
:POSTROUTING ACCEPT [96483:5789063]
-A POSTROUTING -o ${LC_EXTERNAL_DEVICE} -j MASQUERADE
COMMIT" > ${ROOT_MNT}/etc/iptables/rules.v4

## INTERNAL LIGHTTPD FOR SERVING CLOUD_INIT
mkdir -p ${ROOT_MNT}/etc/lighttpd
printf "server.bind 		= \"${LC_INTERNAL_IP}\"
server.port 		= 58087
server.document-root        = \"/var/www/html\"
server.upload-dirs          = ( \"/var/cache/lighttpd/uploads\" )
server.errorlog             = \"/var/log/lighttpd/error.log\"
server.pid-file             = \"/run/lighttpd.pid\"
server.username             = \"www-data\"
server.groupname            = \"www-data\"" > ${ROOT_MNT}/etc/lighttpd/lighttpd.conf

## K3S CONFIG
mkdir -p ${ROOT_MNT}/etc/rancher/k3s
printf "kube-controller-manager-arg:
- \"bind-address=${LC_INTERNAL_IP}\"
kube-proxy-arg:
- \"metrics-bind-address=${LC_INTERNAL_IP}\"
kube-scheduler-arg:
- \"bind-address=${LC_INTERNAL_IP}\"
# Controller Manager exposes etcd sqllite metrics
etcd-expose-metrics: true" > ${ROOT_MNT}/etc/rancher/k3s/config.yaml

## EXTERNAL AVAHI
mkdir -p ${ROOT_MNT}/etc/avahi/
printf "[server]
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
publish-workstation=no" > ${ROOT_MNT}/etc/avahi/avahi-daemon.conf

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
printf "\n${LC_INTERNAL_IP} ${MASTER_HOSTNAME}" >> ${ROOT_MNT}/etc/hosts

#CREATE TFTPBOOT DIRECTORY

mkdir -p ${ROOT_MNT}/tftpboot
echo "CREATED TFTP ROOT"

#CREATE AGENT BASE IMAGE FOR MOUNT
mkdir -p ${ROOT_MNT}${BASEPATH}/boot

### AGENT CONFIG
mkdir -p ${AGENTCONFIGPATH}
AGENTS=$(find ${AGENTCONFIGPATH}/* -maxdepth 0 -type d -printf "%f\n")
FSID=1
for AGENT in ${AGENTS}
do
  ### AGENT NFS MOUNTS
  mkdir -p ${ROOT_MNT}/var/lib/scooby/agents/${AGENT}
  mkdir -p ${ROOT_MNT}/mnt/scooby/agents/${AGENT}

  ### AGENT HOST ENTRY
  AGENT_IP=$(cat ${AGENTCONFIGPATH}/${AGENT}/ip)
  printf "\n${AGENT_IP} ${AGENT}" >> ${ROOT_MNT}/etc/hosts

  ### FSTAB ENTRY
  mkdir -p ${ROOT_MNT}${OVERLAYWORKPATH}/${AGENT}
  printf "\n${AGENT} ${AGENTMOUNTBASE}/${AGENT} overlay nfs_export=on,index=on,defaults,lowerdir=${AGENTCONFIGBASE}/${AGENT}:${BASEPATH},upperdir=${AGENTINSTANCEBASE}/${AGENT},workdir=${OVERLAYWORKPATH}/${AGENT} 0 0\n" >> ${ROOT_MNT}/etc/fstab

  ### EXPORT THE AGENT FS
  printf "\n${AGENTMOUNTBASE}/${AGENT} ${AGENT}(rw,sync,no_subtree_check,no_root_squash,fsid=${FSID})" >> ${ROOT_MNT}/etc/exports

  ### SETUP AGENT TFTPBOOT
  ln -s /mnt/scooby/agents/${AGENT}/boot ${ROOT_MNT}/tftpboot/$(cat ${AGENTCONFIGPATH}/${AGENT}/tftp_client_id)

  ### CREATE AGENT NETWORK BOOT FILES
  mkdir -p ${AGENTCONFIGPATH}/${AGENT}/boot/
  printf "dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 ip=dhcp root=/dev/nfs nfsroot=${LC_INTERNAL_IP}:/mnt/scooby/agents/${AGENT},tcp,vers=3 rw elevator=deadline rootwait ds=nocloud-net;s=http://${LC_INTERNAL_IP}:58087/cloud-config/${AGENT}/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" > ${AGENTCONFIGPATH}/${AGENT}/boot/cmdline.txt
  printf "#cloud-config\n# vim: syntax=yaml\nhostname: ${AGENT}\nmanage_etc_hosts: true\npackage_update: false\npackage_upgrade: false\npackage_reboot_if_required: true\nusers:\n  - default\nruncmd:\n  - sh /usr/local/bin/finalize-cloud-init-agent.sh" > ${AGENTCONFIGPATH}/${AGENT}/boot/user-data
  printf "network:\n  version: 2\n  ethernets:\n    eth0:\n      dhcp4: true" > ${AGENTCONFIGPATH}/${AGENT}/boot/meta-data

  chmod a+x ${AGENTCONFIGPATH}/${AGENT}/boot/cmdline.txt
  chmod a+x ${AGENTCONFIGPATH}/${AGENT}/boot/user-data
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
  printf "proc /proc proc defaults 0 0\n${LC_INTERNAL_IP}:${AGENTMOUNTBASE}/${AGENT} / nfs defaults 0 0\nUUID=\"${AGENT_RANCHER_PART_UUID}\" ${RANCHERSTORAGEPATH} ext4 defaults 0 0" > ${AGENTCONFIGPATH}/${AGENT}/etc/fstab

  ### CREATE AGENT DNSMASQ ENTRY
  AGENT_ETHERNET=$(cat ${AGENTCONFIGPATH}/${AGENT}/ethernet)
  AGENT_IP=$(cat ${AGENTCONFIGPATH}/${AGENT}/ip)
  printf "\ndhcp-host=net:${AGENT},${AGENT_ETHERNET},${AGENT},${AGENT_IP},24h
  dhcp-option=net:${AGENT},17,${LC_INTERNAL_IP}:${AGENTMOUNTBASE}/${AGENT}" >> ${ROOT_MNT}/etc/dnsmasq.conf

  ### COPY BINARIES
  mkdir -p ${AGENTCONFIGPATH}/${AGENT}/usr/local/bin
  rsync -xa --progress -r ${SERVERCONFIGPATH}/usr/local/bin/finalize-cloud-init-agent.sh ${AGENTCONFIGPATH}/${AGENT}/usr/local/bin/
  chmod a+x ${AGENTCONFIGPATH}/${AGENT}/usr/local/bin/finalize-cloud-init-agent.sh

  FSID=$((FSID+1))
done

echo "AGENTS CONFIGURED"

umount ${ROOT_MNT}
umount ${BOOT_MNT}