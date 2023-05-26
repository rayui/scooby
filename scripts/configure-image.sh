BOOT_MNT=/tmp/boot
ROOT_MNT=/tmp/root
VAGRANT=/vagrant
IMGDIR=${VAGRANT}/images
IMGNAME=scooby.img
CONFIGPATH=${VAGRANT}/config
FINALIZEPATH=${VAGRANT}/scripts/finalize-cloud-init.sh

#COPY SERVER ROOT FILESYSTEM

mkdir -p ${ROOT_MNT}
ROOTFSOFFSET=$(sfdisk -o Start -lqqq ${IMGDIR}/${IMGNAME} | tail -n 1 | { read S; echo $((512*$S));})
mount -o loop,offset=${ROOTFSOFFSET} ${IMGDIR}/${IMGNAME} ${ROOT_MNT}
resize2fs /dev/loop0

### HOST CONFIG
rsync -x --progress -r ${CONFIGPATH}/server/etc/* ${ROOT_MNT}/etc
rsync -x --progress -r ${CONFIGPATH}/server/var/* ${ROOT_MNT}/var
rsync -x --progress -r ${CONFIGPATH}/server/usr/* ${ROOT_MNT}/usr
echo "COPIED HOST CONFIG"

mkdir -p ${ROOT_MNT}/tftpboot

echo "CREATED TFTP ROOT"

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

### AGENT CONFIG
mkdir -p ${ROOT_MNT}/etc/scooby/agents
rsync -x --progress -r ${CONFIGPATH}/agents/* ${ROOT_MNT}/etc/scooby/agents
echo "COPIED AGENT CONFIG"

### AGENT NFS MOUNTS
AGENTS=$(find ${CONFIGPATH}/agents/* -maxdepth 0 -type d -printf "%f\n")
for AGENT in ${AGENTS}
do
  mkdir -p ${ROOT_MNT}/var/lib/scooby/agents/${AGENT}
done
echo "CREATED AGENT NFS MOUNTS"

umount ${ROOT_MNT}

#COPY SERVER BOOT FILES
mkdir -p ${BOOT_MNT}
BOOTFSOFFSET=$(sfdisk -o Start -lqqq ${IMGDIR}/${IMGNAME} | tail -n 2 | head -n 1 | { read S; echo $((512*$S));})
mount -o loop,offset=${BOOTFSOFFSET} ${IMGDIR}/${IMGNAME} ${BOOT_MNT}
rsync -x --progress -r ${CONFIGPATH}/server/boot/* ${BOOT_MNT}

echo "COPIED SERVER BOOT FILES"
umount ${BOOT_MNT}