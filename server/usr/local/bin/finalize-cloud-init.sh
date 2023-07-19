#!/bin/sh

IMGDIR=/var/lib/scooby/images
IMGNAME=agent-scooby.img
IMGPATH=${IMGDIR}/${IMGNAME}
BOOT_MNT=/mnt/boot
ROOT_MNT=/mnt/root
LOOP_DEV=/dev/loop0

BASEPATH=/var/lib/scooby/base

AGENTCONFIGPATH=/etc/scooby/agents
AGENTINSTANCEPATH=/var/lib/scooby/agents
AGENTSSHPATH=/var/lib/scooby/ssh
AGENTMOUNTPATH=/mnt/scooby/agents
RANCHERPATH=/var/lib/rancher
OVERLAYWORKPATH=/tmp/overlay/work

#source env vars in sh
. /etc/scooby/.env

#SSH KEYS
ssh-keygen -q -f /home/${LC_DEFAULT_USER}/.ssh/id_ed25519 -N "" -t ed25519
cat /home/${LC_DEFAULT_USER}/.ssh/id_ed25519.pub >> /home/${LC_DEFAULT_USER}/.ssh/authorized_keys
chown -R ${LC_DEFAULT_USER}:${LC_DEFAULT_USER} /home/${LC_DEFAULT_USER}/.ssh/

#GET AGENT IMAGE FROM AWS
mkdir -p ${IMGDIR}
curl -o ${IMGPATH} ${LC_AGENT_IMAGE_HREF}

#MOUNT IMAGE AS LOOP DEVICE
losetup -Pf ${IMGPATH}
mkdir -p ${BOOT_MNT}
mkdir -p ${ROOT_MNT}
mount ${LOOP_DEV}p1 ${BOOT_MNT}
mount ${LOOP_DEV}p2 ${ROOT_MNT}

#COPY IMAGE INTO BASE
mkdir -p ${BASEPATH}/boot
rsync -xa --progress -r ${ROOT_MNT}/* ${BASEPATH}
rsync -xa --progress -r ${BOOT_MNT}/* ${BASEPATH}/boot

#copy bootcode.bin to /tftpboot
rsync -xa --progress ${BOOT_MNT}/bootcode.bin /tftpboot/

#UNMOUNT LOOP DEVICES
umount ${BOOT_MNT}
umount ${ROOT_MNT}
losetup -D ${LOOP_DEV}

AGENTS=$(find ${AGENTCONFIGPATH}/* -maxdepth 0 -type d -printf "%f\n")
FSID=1

for AGENT in ${AGENTS}
do
  #UPDATE MASTER FSTAB
  mkdir -p ${OVERLAYWORKPATH}/${AGENT}
  printf "${AGENT} ${AGENTMOUNTPATH}/${AGENT} overlay nfs_export=on,index=on,defaults,lowerdir=${AGENTCONFIGPATH}/${AGENT}:${BASEPATH},upperdir=${AGENTINSTANCEPATH}/${AGENT},workdir=${OVERLAYWORKPATH}/${AGENT} 0 0\n" >> /etc/fstab
  mount ${AGENTMOUNTPATH}/${AGENT}

  #EXPORT THE AGENT FS
  printf "\n/mnt/scooby/agents/${AGENT} ${AGENT}(rw,sync,no_subtree_check,no_root_squash,fsid=${FSID})" >> /etc/exports

  #SETUP AGENT TFTPBOOT
  ln -s ${AGENTMOUNTPATH}/${AGENT}/boot /tftpboot/$(cat ${AGENTCONFIGPATH}/${AGENT}/tftp_client_id)

  #LINK AGENT CLOUD BOOT CONFIG
  mkdir -p /var/www/html/cloud-config/${AGENT}
  ln -s ${AGENTMOUNTPATH}/${AGENT}/boot/user-data /var/www/html/cloud-config/${AGENT}
  ln -s ${AGENTMOUNTPATH}/${AGENT}/boot/meta-data /var/www/html/cloud-config/${AGENT}

  FSID=$((FSID+1))
done

exportfs -a

#K3S

cd /tmp && curl -sLS https://get.k3sup.dev | sh
# https://github.com/k3s-io/k3s/issues/535#issuecomment-863188327
k3sup install --ip ${LC_INTERNAL_IP} --user ${LC_DEFAULT_USER} --ssh-key "/home/${LC_DEFAULT_USER}/.ssh/id_ed25519" --k3s-extra-args "--node-external-ip=${LC_EXTERNAL_IP} --flannel-iface='${LC_INTERNAL_DEVICE}' --kube-apiserver-arg 'service-node-port-range=1000-32767'"

mkdir -p /root/.kube
rsync -xa --progress ./kubeconfig /root/.kube/config

#READY
wall "BUFFY WILL PATROL TONIGHT"
