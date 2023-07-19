MASTER_HOSTNAME=buffy
BOOT_MNT=/tmp/boot
ROOT_MNT=/tmp/root
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
# printf "version: 2\
# ethernets:\
#   eth0:\
#     dhcp4: false\
#     addresses:\
#       - ${LC_EXTERNAL_IP}/${LC_EXTERNAL_NM}
#     gateway4: ${LC_EXTERNAL_GW}
#     nameservers:
#       search: [${LC_EXTERNAL_DOMAIN}]
#       addresses: [${LC_EXTERNAL_DNS}, ${LC_LOCAL_DNS}]
#   eth1:
#     dhcp4: false
#     gateway4: ${LC_EXTERNAL_IP}
#     addresses:
#       ${LC_INTERNAL_IP}/${LC_INTERNAL_NM}
#     nameservers:
#       search: [${LC_INTERNAL_DOMAIN}]
#       addresses: [${LC_EXTERNAL_DNS}, ${LC_LOCAL_DNS}]" > ${BOOT_MNT}/network-config

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
        ${LC_INTERNAL_IP}/${LC_INTERNAL_NM}
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

### AGENT NFS MOUNTS
mkdir -p ${ROOT_MNT}/etc/scooby/agents
AGENTS=$(find ${ROOT_MNT}/etc/scooby/agents/* -maxdepth 0 -type d -printf "%f\n")
for AGENT in ${AGENTS}
do
  mkdir -p ${ROOT_MNT}/var/lib/scooby/agents/${AGENT}
  mkdir -p ${ROOT_MNT}/mnt/scooby/agents/${AGENT}
done
echo "CREATED AGENT NFS MOUNTS"

#CREATE TFTPBOOT DIRECTORY

mkdir -p ${ROOT_MNT}/tftpboot
echo "CREATED TFTP ROOT"

umount ${ROOT_MNT}
umount ${BOOT_MNT}