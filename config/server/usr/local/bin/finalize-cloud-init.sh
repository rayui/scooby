#!/bin/sh

IMGDIR=/var/lib/scooby/images
IMGNAME=agent-scooby.img
IMGPATH=${IMGDIR}${IMGNAME}
BOOT_MNT=/tmp/mnt/boot
ROOT_MNT=/tmp/mnt/root

AGENTCONFIGPATH=/etc/scooby/agents
AGENTINSTANCEPATH=/var/lib/scooby/agents
AGENTSSHPATH=/var/lib/scooby/ssh

#source env vars in sh
. /etc/scooby/.env

#SSH KEYS
ssh-keygen -q -f /home/${LC_DEFAULT_USER}/.ssh/id_ed25519 -N "" -t ed25519
cat /home/${LC_DEFAULT_USER}/.ssh/id_ed25519.pub >> /home/${LC_DEFAULT_USER}/.ssh/authorized_keys
chown -R ${LC_DEFAULT_USER}:${LC_DEFAULT_USER} /home/${LC_DEFAULT_USER}/.ssh/

#GET AGENT IMAGE FROM AWS
mkdir -p ${IMGDIR}
curl -o ${IMGPATH} ${LC_AGENT_IMAGE_HREF}

#Mount BOOT and configure

mkdir -p ${BOOT_MNT}
BOOTFSOFFSET=$(sfdisk -o Start -lqqq ${IMGPATH} | tail -n 2 | head -n 1 | { read S; echo $((512*$S));})
mount -o loop,offset=${BOOTFSOFFSET} ${IMGPATH} ${BOOT_MNT}

#copy bootcode.bin to /tftpboot
rsync -xa --progress ${BOOT_MNT}/bootcode.bin /tftpboot/

AGENTS=$(find ${AGENTCONFIGPATH}/* -maxdepth 0 -type d -printf "%f\n")
for AGENT in ${AGENTS}
do
  echo "UNPACK AGENT BOOT TO HOST"
  mkdir -p ${AGENTINSTANCEPATH}/${AGENT}/boot/
  rsync -xa --progress ${BOOT_MNT}/* ${AGENTINSTANCEPATH}/${AGENT}/boot/
  rsync -xa --progress -r ${AGENTCONFIGPATH}/${AGENT}/boot/* ${AGENTINSTANCEPATH}/${AGENT}/boot/

  #SETUP AGENT TFTPBOOT
  ln -s ${AGENTINSTANCEPATH}/${AGENT}/boot /tftpboot/$(cat ${AGENTCONFIGPATH}/${AGENT}/tftp_client_id)

  #AGENT CLOUD CONFIG
  mkdir -p /var/www/html/cloud-config/${AGENT}
  ln -s ${AGENTINSTANCEPATH}/${AGENT}/boot/user-data /var/www/html/cloud-config/${AGENT}
  ln -s ${AGENTINSTANCEPATH}/${AGENT}/boot/meta-data /var/www/html/cloud-config/${AGENT}
done

umount ${BOOT_MNT}

#Mount ROOT and configure

mkdir -p ${ROOT_MNT}
ROOTFSOFFSET=$(sfdisk -o Start -lqqq ${IMGPATH} | tail -n 1 | { read S; echo $((512*$S));})
mount -o loop,offset=${ROOTFSOFFSET} ${IMGPATH} ${ROOT_MNT}

AGENTS=$(find ${AGENTCONFIGPATH}/* -maxdepth 0 -type d -printf "%f\n")
for AGENT in $AGENTS
do
  echo "UNPACK AGENT ROOTFS TO HOST"
  mkdir -p ${AGENTINSTANCEPATH}/${AGENT}/
  rsync -xa --progress ${ROOT_MNT}/* ${AGENTINSTANCEPATH}/${AGENT}/

  echo "COPY AGENT FILES TO HOST"
  rsync -xa --progress -r ${AGENTCONFIGPATH}/${AGENT}/etc/* ${AGENTINSTANCEPATH}/${AGENT}/etc/

  mkdir -p ${AGENTINSTANCEPATH}/${AGENT}/usr/local/bin
  rsync -xa --progress -r usr/local/bin/finalize-cloud-init-agent.sh ${AGENTINSTANCEPATH}/${AGENT}/usr/local/bin/

  #AGENT KEYS
  mkdir -p ${AGENTINSTANCEPATH}/${AGENT}${AGENTSSHPATH}/
  rsync -xa --progress /home/${LC_DEFAULT_USER}/.ssh/id_ed25519 ${AGENTINSTANCEPATH}/${AGENT}${AGENTSSHPATH}/${LC_DEFAULT_USER}_ed25519_key
  rsync -xa --progress /home/${LC_DEFAULT_USER}/.ssh/id_ed25519.pub ${AGENTINSTANCEPATH}/${AGENT}${AGENTSSHPATH}/${LC_DEFAULT_USER}_ed25519_key.pub
done

umount ${ROOT_MNT}

#K3S

cd /tmp && curl -sLS https://get.k3sup.dev | sh
# https://github.com/k3s-io/k3s/issues/535#issuecomment-863188327
k3sup install --ip ${LC_INTERNAL_IP} --user ${LC_DEFAULT_USER} --ssh-key "/home/${LC_DEFAULT_USER}/.ssh/id_ed25519" --k3s-extra-args "--node-external-ip=${LC_EXTERNAL_IP} --flannel-iface='${LC_INTERNAL_DEVICE}' --kube-apiserver-arg 'service-node-port-range=1000-32767'"

mkdir -p /root/.kube
rsync -xa --progress ./kubeconfig /root/.kube/config

#READY
wall "BUFFY WILL PATROL TONIGHT"
