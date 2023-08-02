#!/bin/sh

resizeImage() {
  ### RESIZE IMAGE
  
  ROOTSTARTSECTOR=$(sfdisk -l -o Start ${VAGRANT_IMAGE} | tail -n 1)
  dd if=/dev/zero bs=1M count=2000 status=progress >> ${VAGRANT_IMAGE}
  sfdisk --delete ${VAGRANT_IMAGE} 2
  printf "${ROOTSTARTSECTOR},+,L" | sfdisk -a ${VAGRANT_IMAGE}

  losetup -Pf ${VAGRANT_IMAGE}
  e2fsck -y -f ${LOOP_DEV}p2
  resize2fs ${LOOP_DEV}p2
  losetup -D
}