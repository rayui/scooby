#!/bin/sh

cloneBaseImage() {
  losetup -Pf ${VAGRANT_IMAGE}

  DISK_ID=$(blkid --match-tag PARTUUID ${LOOP_DEV}p1 | grep -oE "[a-f0-9]{8}")
  BOOTSIZE=$(sfdisk -l -o Sectors ${VAGRANT_IMAGE} | tail -n 2 | head -n 1)
  ROOTSIZE=$(sfdisk -l -o Sectors ${VAGRANT_IMAGE} | tail -n 1)
    
  dd if=${LOOP_DEV}p1 bs=1M status=progress >> ${VAGRANT_IMAGE}
  dd if=${LOOP_DEV}p2 bs=1M status=progress >> ${VAGRANT_IMAGE}

  losetup -D

  printf ",${BOOTSIZE},0c\n,${ROOTSIZE},83" | sfdisk -a ${VAGRANT_IMAGE}
  sfdisk --disk-id "${VAGRANT_IMAGE}" 0x${DISK_ID}
}