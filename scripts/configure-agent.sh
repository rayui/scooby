#!/bin/sh

createAgentBase() {
  #MOUNT IMAGE AS LOOP DEVICE
  mkdir -p ${BOOT_MNT}
  mkdir -p ${ROOT_MNT}
  mount ${LOOP_DEV}p1 ${BOOT_MNT}
  mount ${LOOP_DEV}p2 ${ROOT_MNT}

  #COPY IMAGE INTO BASE
  mkdir -p ${ROOT_MNT}${BASE_DIR}/boot
  BASE_DIR_RELATIVE=$(printf "${BASE_DIR}" | grep -oE "[^\/].*$")
  rsync -xa --stats --exclude="${BASE_DIR_RELATIVE}" ${ROOT_MNT}/* ${ROOT_MNT}${BASE_DIR}/
  rsync -xa --stats ${BOOT_MNT}/* ${ROOT_MNT}${BASE_DIR}/boot

  #UNMOUNT LOOP DEVICES
  umount ${BOOT_MNT}
  umount ${ROOT_MNT}
}

configureAgent() {

AGENT=${1}

SCOOBY_DIR=/var/lib/scooby
BASE_DIR=${SCOOBY_DIR}/base
SSH_DIR=${SCOOBY_DIR}/ssh
MOUNT_DIR=/mnt/scooby/agents
RANCHERSTORAGEPATH=/var/lib/rancher

AGENT_ROOT=${ROOT_MNT}${CONFIG_DIR}/${AGENT}

printf "\nCONFIGURING AGENT ${AGENT}\n"

### AGENT HOST ENTRY
cat - >> ${ROOT_MNT}/etc/hosts << EOF
${AGENT_IP} ${AGENT}
EOF

### OVERLAYFS AND FSTAB ENTRY
mkdir -p ${ROOT_MNT}${SCOOBY_DIR}/agents/${AGENT}
mkdir -p ${ROOT_MNT}${MOUNT_DIR}/${AGENT}
mkdir -p ${ROOT_MNT}${SCOOBY_DIR}/overlay/${AGENT}

cat - >> ${ROOT_MNT}/etc/fstab << EOF
${AGENT} ${MOUNT_DIR}/${AGENT} overlay nfs_export=on,index=on,defaults,lowerdir=${CONFIG_DIR}/${AGENT}:${BASE_DIR},upperdir=${SCOOBY_DIR}/agents/${AGENT},workdir=${SCOOBY_DIR}/overlay/${AGENT} 0 0
EOF

### EXPORT THE AGENT WITH NFS
cat - >> ${ROOT_MNT}/etc/exports << EOF
${MOUNT_DIR}/${AGENT} ${AGENT}(rw,sync,no_subtree_check,no_root_squash,fsid=${FSID})
EOF

### SETUP AGENT TFTPBOOT
ln -s ${MOUNT_DIR}/${AGENT}/boot ${ROOT_MNT}/tftpboot/${AGENT_PXE_ID}

### CREATE AGENT NETWORK BOOT FILES
mkdir -p ${AGENT_ROOT}/boot/

### CREATE AGENT CMDLINE.TXT
cat - > ${AGENT_ROOT}/boot/cmdline.txt << EOF
dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 ip=dhcp root=/dev/nfs nfsroot=${LC_INTERNAL_IP}:${MOUNT_DIR}/${AGENT},tcp,vers=3 rw elevator=deadline rootwait ds=nocloud-net;s=http://${LC_INTERNAL_IP}:58087/cloud-config/${AGENT}/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
EOF
chmod a+x ${AGENT_ROOT}/boot/cmdline.txt

### CREATE AGENT USER-DATA
cat - > ${AGENT_ROOT}/boot/user-data << EOF
#cloud-config
# vim: syntax=yaml
hostname: ${AGENT}
manage_etc_hosts: true
package_update: false
package_upgrade: false
package_reboot_if_required: true
users:
  - default
runcmd:
  - sh /usr/local/bin/finalize-cloud-init-agent.sh
EOF
chmod a+x ${AGENT_ROOT}/boot/user-data

### CREATE AGENT META-DATA
cat - > ${AGENT_ROOT}/boot/meta-data << EOF
network:
  version: 2
  ethernets:
    ${LC_EXTERNAL_DEVICE}:
      dhcp4: true
EOF
chmod a+x ${AGENT_ROOT}/boot/meta-data  

### LINK AGENT CLOUD BOOT CONFIG
CLOUDCONFIGWWWPATH=${ROOT_MNT}/var/www/html/cloud-config

mkdir -p ${CLOUDCONFIGWWWPATH}/${AGENT}
ln -s ${CONFIG_DIR}/${AGENT}/boot/user-data ${CLOUDCONFIGWWWPATH}/${AGENT}
ln -s ${CONFIG_DIR}/${AGENT}/boot/meta-data ${CLOUDCONFIGWWWPATH}/${AGENT}

### Local mount point for rancher see here: https://github.com/containerd/containerd/issues/5464
mkdir -p ${AGENT_ROOT}${RANCHERSTORAGEPATH}

### CREATE AGENT FSTAB
mkdir -p ${AGENT_ROOT}/etc/

cat - > ${AGENT_ROOT}/etc/fstab << EOF
proc /proc proc defaults 0 0
${LC_INTERNAL_IP}:${MOUNT_DIR}/${AGENT} / nfs defaults 0 0
UUID="${AGENT_RANCHER_PART_UUID}" ${RANCHERSTORAGEPATH} ext4 defaults 0 0
EOF

### CREATE AGENT DNSMASQ ENTRY
cat - > ${ROOT_MNT}/etc/dnsmasq.d/20-scooby-agent-${AGENT} << EOF
dhcp-host=net:${AGENT},${AGENT_ETHERNET},${AGENT},${AGENT_IP},24h
dhcp-option=net:${AGENT},17,${LC_INTERNAL_IP}:${MOUNT_DIR}/${AGENT}
EOF

### CREATE AGENT FIRST BOOT CONFIGURATION

mkdir -p ${AGENT_ROOT}/usr/local/bin
cat - > ${AGENT_ROOT}/usr/local/bin/finalize-cloud-init-agent.sh << EOF
#!/bin/sh

cp ${SSH_DIR}/* /home/${LC_DEFAULT_USER}/.ssh/

cd /tmp && curl -sLS https://get.k3sup.dev | sh
k3sup join \
--ip ${AGENT_IP} \
--server-ip ${LC_INTERNAL_IP} \
--user ${LC_DEFAULT_USER} \
--server-user ${LC_DEFAULT_USER} \
--ssh-key "${SSH_DIR}/id_ed25519" \
--k3s-extra-args "--node-name '${AGENT}' ${AGENT_K3S_ARGS}"

wall "${AGENT} IS ONLINE"
EOF
chmod a+x ${AGENT_ROOT}/usr/local/bin/finalize-cloud-init-agent.sh 

}

configureAgents() {
  mkdir -p ${ROOT_MNT}
  mount ${LOOP_DEV}p2 ${ROOT_MNT}

  ### AGENT CONFIG
  mkdir -p ${ROOT_MNT}${CONFIG_DIR}
  
  if [ -d ${AGENT_DIR} ] && ls ${AGENT_DIR}/*.agent 1> /dev/null 2>&1; then
    FSID=1
    for FILE in $(cd ${AGENT_DIR}; ls *.agent)
    do
      . ${AGENT_DIR}/${FILE}
      configureAgent $(printf "${FILE}" | grep -oE "^[a-z0-9\-]+")
      FSID=$((FSID+1))
    done
  fi

  umount ${ROOT_MNT}
}
