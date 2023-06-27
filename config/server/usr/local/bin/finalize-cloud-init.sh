#!/bin/sh

IMGDIR=/var/lib/scooby/images
IMGNAME=agent-scooby.img
IMGPATH=${IMGDIR}/${IMGNAME}
BOOT_MNT=/mnt/boot
ROOT_MNT=/mnt/root

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

#MOUNT IMAGE AS LOOP DEVICE
losetup -Pf ${IMGPATH}
mkdir -p ${BOOT_MNT}/boot
mkdir -p ${ROOT_MNT}
mount /dev/loop0p1 ${BOOT_MNT}/boot
mount /dev/loop0p2 ${ROOT_MNT}

#copy bootcode.bin to /tftpboot
rsync -xa --progress ${BOOT_MNT}/boot/bootcode.bin /tftpboot/

AGENTS=$(find ${AGENTINSTANCEPATH}/* -maxdepth 0 -type d -printf "%f\n")
for AGENT in ${AGENTS}
do
  echo "MOUNT AGENT UNION FS DIRECTORY"
  mount -t unionfs -o dirs=${AGENTINSTANCEPATH}/${AGENT}:${AGENTCONFIGPATH}/${AGENT}=ro:${BOOT_MNT}=ro:${ROOT_MNT}=ro none ${AGENTINSTANCEPATH}/${AGENT}

  #COPY BINARIES
  mkdir -p ${AGENTINSTANCEPATH}/${AGENT}/usr/local/bin
  rsync -xa --progress -r usr/local/bin/finalize-cloud-init-agent.sh ${AGENTINSTANCEPATH}/${AGENT}/usr/local/bin/

  #AGENT KEYS
  mkdir -p ${AGENTINSTANCEPATH}/${AGENT}${AGENTSSHPATH}/
  rsync -xa --progress /home/${LC_DEFAULT_USER}/.ssh/id_ed25519 ${AGENTINSTANCEPATH}/${AGENT}${AGENTSSHPATH}/${LC_DEFAULT_USER}_ed25519_key
  rsync -xa --progress /home/${LC_DEFAULT_USER}/.ssh/id_ed25519.pub ${AGENTINSTANCEPATH}/${AGENT}${AGENTSSHPATH}/${LC_DEFAULT_USER}_ed25519_key.pub

  #SETUP AGENT TFTPBOOT
  ln -s ${AGENTINSTANCEPATH}/${AGENT}/boot /tftpboot/$(cat ${AGENTCONFIGPATH}/${AGENT}/tftp_client_id)

  #AGENT CLOUD CONFIG
  mkdir -p /var/www/html/cloud-config/${AGENT}
  ln -s ${AGENTINSTANCEPATH}/${AGENT}/boot/user-data /var/www/html/cloud-config/${AGENT}
  ln -s ${AGENTINSTANCEPATH}/${AGENT}/boot/meta-data /var/www/html/cloud-config/${AGENT}
done

#K3S

cd /tmp && curl -sLS https://get.k3sup.dev | sh
# https://github.com/k3s-io/k3s/issues/535#issuecomment-863188327
k3sup install --ip ${LC_INTERNAL_IP} --user ${LC_DEFAULT_USER} --ssh-key "/home/${LC_DEFAULT_USER}/.ssh/id_ed25519" --k3s-extra-args "--node-external-ip=${LC_EXTERNAL_IP} --flannel-iface='${LC_INTERNAL_DEVICE}' --kube-apiserver-arg 'service-node-port-range=1000-32767'"

mkdir -p /root/.kube
rsync -xa --progress ./kubeconfig /root/.kube/config

#READY
wall "BUFFY WILL PATROL TONIGHT"
