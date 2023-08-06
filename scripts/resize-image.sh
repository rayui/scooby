#!/bin/sh

resizeImage() {
  ### RESIZE IMAGE
  
  LOOP_DEV=$(losetup -Pf --show ${VAGRANT_IMAGE})
  printf "SQUASHING ROOT PARTITION"
  e2fsck -y -f ${LOOP_DEV}p2
  resize2fs -M ${LOOP_DEV}p2
  COPYBLOCKS=$((($(blockdev --getsize64 ${LOOP_DEV}p2) >> 20) + 1))
  losetup -D

  printf "EXPANDING BASE IMAGE BY ${COPYBLOCKS} MEGABYTES PLEASE WAIT..."
  dd if=/dev/zero bs=1M count=${COPYBLOCKS} status=noxfer >> ${VAGRANT_IMAGE}
  sfdisk --delete ${VAGRANT_IMAGE} 2
  
  ROOTSTARTSECTOR=$(sfdisk -l -o Start ${VAGRANT_IMAGE} | tail -n 1)
  printf "${ROOTSTARTSECTOR},+,L" | sfdisk -a ${VAGRANT_IMAGE}

  LOOP_DEV=$(losetup -Pf --show ${VAGRANT_IMAGE})
  printf "EXPANDING ROOT PARTITION"
  e2fsck -y -f ${LOOP_DEV}p2
  resize2fs ${LOOP_DEV}p2
  losetup -D
}
