#!/bin/sh

resizeImage() {
  VAGRANT=/vagrant
  LOOP_DEV=/dev/loop0
  IMAGEPATH=${VAGRANT}/images/scooby.img

  ### RESIZE IMAGE
  
  ROOTSTARTSECTOR=$(sfdisk -l -o Start ${IMAGEPATH} | tail -n 1)
  dd if=/dev/zero bs=1M count=2000 status=progress >> ${IMAGEPATH}
  sfdisk --delete ${IMAGEPATH} 2
  printf "${ROOTSTARTSECTOR},+,L" | sfdisk -a ${IMAGEPATH}

  losetup -Pf ${IMAGEPATH}
  e2fsck -y -f ${LOOP_DEV}p2
  resize2fs ${LOOP_DEV}p2
  losetup -D
}