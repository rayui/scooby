#!/bin/sh

configureBoot() {

BOOT_MNT=/tmp/boot

mkdir -p ${BOOT_MNT}
mount ${LOOP_DEV}p1 ${BOOT_MNT}

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

### FINISHED WITH BOOT MOUNT
umount ${BOOT_MNT}

}