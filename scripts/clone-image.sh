#!/bin/sh

cloneBaseImage() {
  losetup -Pf ${VAGRANT_IMAGE}

  BOOTSIZE=$(sfdisk -l -o Sectors ${VAGRANT_IMAGE} | tail -n 2 | head -n 1)
  ROOTSIZE=$(sfdisk -l -o Sectors ${VAGRANT_IMAGE} | tail -n 1)
  
  dd if=${LOOP_DEV}p1 bs=1M status=progress >> ${VAGRANT_IMAGE}
  dd if=${LOOP_DEV}p2 bs=1M status=progress >> ${VAGRANT_IMAGE}

  dosfslabel ${LOOP_DEV}p1 SCOOBY

  losetup -D

  printf ",${BOOTSIZE},0c\n,${ROOTSIZE},83" | sfdisk -a ${VAGRANT_IMAGE}
  sfdisk --disk-id "${VAGRANT_IMAGE}" "0x${DISK_ID}"

  #MAKE BOOTABLE
  sfdisk -A -N 1 ${VAGRANT_IMAGE}

}