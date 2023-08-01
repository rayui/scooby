#!/bin/sh

configureBoot() {

losetup -Pf ${VAGRANT_IMAGE}

INTERNAL_MASK=$(printf "${LC_INTERNAL_NET}" | awk -F/ '{print $2}')
EXTERNAL_MASK=$(printf "${LC_EXTERNAL_NET}" | awk -F/ '{print $2}')

mkdir -p ${BOOT_MNT}
mount ${LOOP_DEV}p1 ${BOOT_MNT}

### CREATE SERVER CMDLINE.TXT
cat - > ${BOOT_MNT}/cmdline.txt << EOF
console=serial0,115200 console=tty1 root=PARTUUID=${DISK_ID}-04 rootfstype=ext4 fsck.repair=yes rootwait quiet init=/usr/lib/raspi-config/init_resize.sh cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
EOF
chmod a+x ${BOOT_MNT}/cmdline.txt

### SET UP SERVER BOOT CONFIG
cat - > ${BOOT_MNT}/network-config << EOF
version: 2
ethernets:
  ${LC_EXTERNAL_DEVICE}:
    dhcp4: false
    addresses:
    - ${LC_EXTERNAL_IP}/${EXTERNAL_MASK}
    gateway4: ${LC_EXTERNAL_GW}
    nameservers:
      search: [${LC_EXTERNAL_DOMAIN}]
      addresses: [${LC_PRIMARY_DNS}, ${LC_SECONDARY_DNS}]
  ${LC_INTERNAL_DEVICE}:
    dhcp4: false
    gateway4: ${LC_EXTERNAL_IP}
    addresses:
    - ${LC_INTERNAL_IP}/${INTERNAL_MASK}
    nameservers:
      search: [${LC_INTERNAL_DOMAIN}]
      addresses: [${LC_PRIMARY_DNS}, ${LC_SECONDARY_DNS}]
EOF
chmod a+x ${BOOT_MNT}/network-config

cat - > ${BOOT_MNT}/meta-data << EOF
network:
  version: 2
  ethernets:
    ${LC_EXTERNAL_DEVICE}:
      dhcp4: false
      addresses:
      - ${LC_EXTERNAL_IP}/${EXTERNAL_MASK}
      gateway4: ${LC_EXTERNAL_GW}
      nameservers:
        search: [${LC_EXTERNAL_DOMAIN}]
        addresses: [${LC_PRIMARY_DNS}, ${LC_SECONDARY_DNS}]
    ${LC_INTERNAL_DEVICE}:
      dhcp4: false
      gateway4: ${LC_EXTERNAL_IP}
      addresses:
      - ${LC_INTERNAL_IP}/${INTERNAL_MASK}
      nameservers:
        search: [${LC_INTERNAL_DOMAIN}]
        addresses: [${LC_PRIMARY_DNS}, ${LC_SECONDARY_DNS}]
EOF
chmod a+x ${BOOT_MNT}/meta-data

cat - > ${BOOT_MNT}/user-data << EOF
#cloud-config
# vim: syntax=yaml
hostname: ${LC_HOSTNAME}
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

### FINISHED WITH BOOT MOUNT
umount ${BOOT_MNT}

losetup -D

}