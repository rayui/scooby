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