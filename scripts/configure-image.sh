MASTER_HOSTNAME=buffy
BOOT_MNT=/tmp/boot
ROOT_MNT=/tmp/root
AGENTCONFIGPATH=${ROOT_MNT}/etc/scooby/agents
VAGRANT=/vagrant
IMGPATH=${VAGRANT}/images/scooby.img
SERVERCONFIGPATH=${VAGRANT}/server
FINALIZEPATH=${VAGRANT}/scripts/finalize-cloud-init.sh

#MOUNT IMAGE AS LOOP DEVICE
losetup -Pf ${IMGPATH}
mkdir -p ${BOOT_MNT}
mkdir -p ${ROOT_MNT}
mount /dev/loop0p1 ${BOOT_MNT}
mount /dev/loop0p2 ${ROOT_MNT}

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
  - /usr/local/bin/finalize-cloud-init.sh" > ${BOOT_MNT}/user-data

DHCP_RANGE=$(echo ${LC_INTERNAL_IP} | grep -Eo '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}')
printf "port=53
domain=${LC_INTERNAL_DOMAIN}

interface=${LC_INTERNAL_DEVICE}
bind-interfaces
dhcp-authoritative

expand-hosts
log-dhcp
#dhcp-ignore=tag:!known

dhcp-range=tag:${LC_INTERNAL_DEVICE},${DHCP_RANGE}192,${DHCP_RANGE}.254
dhcp-option=tag:${LC_INTERNAL_DEVICE},66,${LC_INTERNAL_IP}
dhcp-option=tag:${LC_INTERNAL_DEVICE},option:router,${LC_INTERNAL_IP}
dhcp-option=tag:${LC_INTERNAL_DEVICE},6,${LC_INTERNAL_IP}

enable-tftp
tftp-root=/tftpboot/
pxe-service=0,\"Raspberry Pi Boot\"\n" > ${ROOT_MNT}/etc/dnsmasq.conf

### COPY SERVER FILES
rsync -x --progress -r ${SERVERCONFIGPATH}/boot/* ${BOOT_MNT}/
rsync -x --progress -r ${SERVERCONFIGPATH}/etc/* ${ROOT_MNT}/etc/
rsync -x --progress -r ${SERVERCONFIGPATH}/var/* ${ROOT_MNT}/var/
rsync -x --progress -r ${SERVERCONFIGPATH}/usr/* ${ROOT_MNT}/usr/
echo "COPIED SERVER FILES"

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
printf "\n{LC_INTERNAL_IP} ${MASTER_HOSTNAME}" >> ${ROOT_MNT}/etc/hosts

### AGENT CONFIG
mkdir -p ${ROOT_MNT}/etc/scooby/agents
AGENTS=$(find ${AGENTCONFIGPATH}/* -maxdepth 0 -type d -printf "%f\n")
for AGENT in ${AGENTS}
do
  ### AGENT NFS MOUNTS
  mkdir -p ${ROOT_MNT}/var/lib/scooby/agents/${AGENT}
  mkdir -p ${ROOT_MNT}/mnt/scooby/agents/${AGENT}

  ### AGENT HOST ENTRY
  AGENT_IP=$(cat ${AGENTCONFIGPATH}/${AGENT}/ip)
  printf "\n${AGENT_IP} ${AGENT}" >> ${ROOT_MNT}/etc/hosts

  #CREATE AGENT NETWORK BOOT FILES
  mkdir -p ${AGENTCONFIGPATH}/${AGENT}/boot/
  printf "dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 ip=dhcp root=/dev/nfs nfsroot=${LC_INTERNAL_IP}:/mnt/scooby/agents/${AGENT},tcp,vers=3 rw elevator=deadline rootwait ds=nocloud-net;s=http://${LC_INTERNAL_IP}:58087/cloud-config/${AGENT}/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" > ${AGENTCONFIGPATH}/${AGENT}/boot/cmdline.txt
  printf "#cloud-config\n# vim: syntax=yaml\nhostname: ${AGENT}\nmanage_etc_hosts: true\npackage_update: false\npackage_upgrade: false\npackage_reboot_if_required: true\nusers:\n  - default\nruncmd:\n  - sh /usr/local/bin/finalize-cloud-init-agent.sh" > ${AGENTCONFIGPATH}/${AGENT}/boot/user-data

  #CREATE AGENT FSTAB
  mkdir -p ${AGENTCONFIGPATH}/${AGENT}/etc/
  AGENT_RANCHER_PART_UUID=$(cat ${AGENTCONFIGPATH}/${AGENT}/rancher_partition_uuid)
  printf "proc /proc proc defaults 0 0\n${LC_INTERNAL_IP}:/mnt/scooby/agents/${AGENT} / nfs defaults 0 0\nUUID=\"${AGENT_RANCHER_PART_UUID}\" /var/lib/rancher ext4 defaults 0 0" > ${AGENTCONFIGPATH}/${AGENT}/etc/fstab

  #CREATE AGENT DNSMASQ ENTRY
  AGENT_ETHERNET=$(cat ${AGENTCONFIGPATH}/${AGENT}/ethernet)
  AGENT_IP=$(cat ${AGENTCONFIGPATH}/${AGENT}/ip)
  printf "\ndhcp-host=net:${AGENT},${AGENT_ETHERNET},${AGENT},${AGENT_IP},24h
  dhcp-option=net:${AGENT},17,${LC_INTERNAL_IP}:${AGENTMOUNTPATH}/${AGENT}" >> /etc/dnsmasq.conf


  # local mount point for rancher see here: https://github.com/containerd/containerd/issues/5464
  mkdir -p ${AGENTCONFIGPATH}/${AGENT}${RANCHERPATH}

  #COPY BINARIES
  mkdir -p ${AGENTCONFIGPATH}/${AGENT}/usr/local/bin
  rsync -xa --progress -r /usr/local/bin/finalize-cloud-init-agent.sh ${AGENTCONFIGPATH}/${AGENT}/usr/local/bin/

  #COPY AGENT KEYS FOR K3S
  mkdir -p ${AGENTCONFIGPATH}/${AGENT}${AGENTSSHPATH}/
  rsync -xa --progress /home/${LC_DEFAULT_USER}/.ssh/id_ed25519 ${AGENTCONFIGPATH}/${AGENT}${AGENTSSHPATH}/${LC_DEFAULT_USER}_ed25519_key
  rsync -xa --progress /home/${LC_DEFAULT_USER}/.ssh/id_ed25519.pub ${AGENTCONFIGPATH}/${AGENT}${AGENTSSHPATH}/${LC_DEFAULT_USER}_ed25519_key.pub
done

echo "AGENTS CONFIGURED"

#CREATE TFTPBOOT DIRECTORY

mkdir -p ${ROOT_MNT}/tftpboot
echo "CREATED TFTP ROOT"

umount ${ROOT_MNT}
umount ${BOOT_MNT}