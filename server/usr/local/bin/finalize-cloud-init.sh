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
for AGENT in ${AGENTS}
do
  echo "MOUNT AGENT UNION FS DIRECTORY"
  mkdir -p ${OVERLAYWORKPATH}/${AGENT}
  printf "${AGENT} ${AGENTMOUNTPATH}/${AGENT} overlay nfs_export=on,index=on,defaults,lowerdir=${AGENTCONFIGPATH}/${AGENT}:${BASEPATH},upperdir=${AGENTINSTANCEPATH}/${AGENT},workdir=${OVERLAYWORKPATH}/${AGENT} 0 0\n" >> /etc/fstab
  mount ${AGENTMOUNTPATH}/${AGENT}

  mkdir -p ${AGENTCONFIGPATH}/${AGENT}/boot/
  mkdir -p ${AGENTCONFIGPATH}/${AGENT}/etc/

  AGENT_RANCHER_PART_UUID=$(cat ${AGENTCONFIGPATH}/${AGENT}/rancher_partition_uuid)

  printf "dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 ip=dhcp root=/dev/nfs nfsroot=${LC_INTERNAL_IP}:/mnt/scooby/agents/${AGENT},tcp,vers=3 rw elevator=deadline rootwait ds=nocloud-net;s=http://${LC_INTERNAL_IP}:58087/cloud-config/${AGENT}/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" > ${AGENTCONFIGPATH}/${AGENT}/boot/cmdline.txt
  printf "#cloud-config\n# vim: syntax=yaml\nhostname: ${AGENT}\nmanage_etc_hosts: true\npackage_update: false\npackage_upgrade: false\npackage_reboot_if_required: true\nusers:\n  - default\nruncmd:\n  - sh /usr/local/bin/finalize-cloud-init-agent.sh" > ${AGENTCONFIGPATH}/${AGENT}/boot/user-data
  printf "proc /proc proc defaults 0 0\n${LC_INTERNAL_IP}:/mnt/scooby/agents/${AGENT} / nfs defaults 0 0\nUUID=\"${AGENT_RANCHER_PART_UUID}\" /var/lib/rancher ext4 defaults 0 0" > ${AGENTCONFIGPATH}/${AGENT}/etc/fstab

  #COPY BINARIES
  mkdir -p ${AGENTCONFIGPATH}/${AGENT}/usr/local/bin
  rsync -xa --progress -r /usr/local/bin/finalize-cloud-init-agent.sh ${AGENTCONFIGPATH}/${AGENT}/usr/local/bin/

  #AGENT KEYS
  mkdir -p ${AGENTCONFIGPATH}/${AGENT}${AGENTSSHPATH}/
  rsync -xa --progress /home/${LC_DEFAULT_USER}/.ssh/id_ed25519 ${AGENTCONFIGPATH}/${AGENT}${AGENTSSHPATH}/${LC_DEFAULT_USER}_ed25519_key
  rsync -xa --progress /home/${LC_DEFAULT_USER}/.ssh/id_ed25519.pub ${AGENTCONFIGPATH}/${AGENT}${AGENTSSHPATH}/${LC_DEFAULT_USER}_ed25519_key.pub

  #SETUP AGENT TFTPBOOT
  ln -s ${AGENTMOUNTPATH}/${AGENT}/boot /tftpboot/$(cat ${AGENTCONFIGPATH}/${AGENT}/tftp_client_id)

  #AGENT CLOUD CONFIG
  mkdir -p /var/www/html/cloud-config/${AGENT}
  ln -s ${AGENTMOUNTPATH}/${AGENT}/boot/user-data /var/www/html/cloud-config/${AGENT}
  ln -s ${AGENTMOUNTPATH}/${AGENT}/boot/meta-data /var/www/html/cloud-config/${AGENT}

  # local mount point for rancher see here: https://github.com/containerd/containerd/issues/5464
  mkdir -p ${AGENTCONFIGPATH}/${AGENT}${RANCHERPATH}
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
