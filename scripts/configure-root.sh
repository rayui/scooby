#!/bin/sh

importAgentImage() {
  TMP_BOOT=/tmp/agent-boot
  TMP_ROOT=/tmp/agent-root

  #MOUNT IMAGE AS LOOP DEVICE
  losetup -Pf ${VAGRANT}/images/scooby-agent.img
  mkdir -p ${BOOT_MNT}
  mkdir -p ${ROOT_MNT}
  mkdir -p ${TMP_BOOT}
  mkdir -p ${TMP_ROOT}
  mount ${LOOP_DEV}p2 ${ROOT_MNT}
  mount ${LOOP_DEV2}p1 ${TMP_BOOT}
  mount ${LOOP_DEV2}p2 ${TMP_ROOT}

  #COPY IMAGE INTO BASE
  mkdir -p ${ROOT_MNT}${BASE_DIR}/boot
  rsync -xa --progress -r ${TMP_ROOT}/* ${ROOT_MNT}${BASE_DIR}
  rsync -xa --progress -r ${TMP_BOOT}/* ${ROOT_MNT}${BASE_DIR}/boot

  #PUT BOOTCODE.BIN IN TFTPBOOT
  rsync -xa --progress ${TMP_BOOT}/bootcode.bin ${ROOT_MNT}/tftpboot/

  #UNMOUNT LOOP DEVICES
  umount ${TMP_BOOT}
  umount ${TMP_ROOT}
  umount ${ROOT_MNT}
}

configureRoot() {
INTERNAL_NET=$(printf "${LC_INTERNAL_NET}" | awk -F/ '{print $1}')

mkdir -p ${ROOT_MNT}
mount ${LOOP_DEV}p2 ${ROOT_MNT}

### COPY STATIC CONFIG
rsync -x --progress -r ${VAGRANT}/server/* ${ROOT_MNT}
printf "COPIED STATIC CONFIG\n"

### BASE SERVICES CONFIG
## INTERNAL DNSMASQ
cat - > ${ROOT_MNT}/etc/dnsmasq.conf << EOF
port=0
bind-interfaces
dhcp-authoritative

expand-hosts
log-dhcp
EOF

cat - > ${ROOT_MNT}/etc/dnsmasq.d/10-scooby-dhcp.conf << EOF
domain=${LC_INTERNAL_DOMAIN}
interface=${LC_INTERNAL_DEVICE}

dhcp-range=tag:${LC_INTERNAL_DEVICE},${INTERNAL_NET},static
dhcp-option=tag:${LC_INTERNAL_DEVICE},66,${LC_INTERNAL_IP}
dhcp-option=tag:${LC_INTERNAL_DEVICE},option:router,${LC_INTERNAL_IP}
dhcp-option=tag:${LC_INTERNAL_DEVICE},6,${LC_PRIMARY_DNS}

enable-tftp=${LC_INTERNAL_DEVICE}
tftp-root=/tftpboot/
pxe-service=0,"Raspberry Pi Boot"
EOF

## ALLOW AGENTS INTERNET ACCESS
mkdir -p ${ROOT_MNT}/etc/iptables
cat - > ${ROOT_MNT}/etc/iptables/rules.v4 << EOF
*filter
:INPUT ACCEPT
:FORWARD ACCEPT
:OUTPUT ACCEPT
-A FORWARD -i ${LC_EXTERNAL_DEVICE} -o ${LC_INTERNAL_DEVICE} -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i ${LC_INTERNAL_DEVICE} -o ${LC_EXTERNAL_DEVICE} -j ACCEPT
COMMIT
*nat
:PREROUTING ACCEPT
:INPUT ACCEPT
:OUTPUT ACCEPT
:POSTROUTING ACCEPT
-A POSTROUTING -o ${LC_EXTERNAL_DEVICE} -j MASQUERADE
COMMIT
EOF

## INTERNAL LIGHTTPD FOR SERVING CLOUD_INIT
mkdir -p ${ROOT_MNT}/etc/lighttpd
cat - > ${ROOT_MNT}/etc/lighttpd/lighttpd.conf << EOF
server.bind 		= "${LC_INTERNAL_IP}"
server.port 		= 58087
server.document-root        = "/var/www/html"
server.upload-dirs          = ( "/var/cache/lighttpd/uploads" )
server.errorlog             = "/var/log/lighttpd/error.log"
server.pid-file             = "/run/lighttpd.pid"
server.username             = "www-data"
server.groupname            = "www-data"
EOF

## K3S CONFIG
mkdir -p ${ROOT_MNT}/etc/rancher/k3s
cat - > ${ROOT_MNT}/etc/rancher/k3s/config.yaml << EOF
kube-controller-manager-arg:
- "bind-address=${LC_INTERNAL_IP}"
kube-proxy-arg:
- "metrics-bind-address=${LC_INTERNAL_IP}"
kube-scheduler-arg:
- "bind-address=${LC_INTERNAL_IP}"
# Controller Manager exposes etcd sqllite metrics
etcd-expose-metrics: true
EOF

## EXTERNAL AVAHI
mkdir -p ${ROOT_MNT}/etc/avahi/
cat - > ${ROOT_MNT}/etc/avahi/avahi-daemon.conf << EOF
[server]
use-ipv4=yes
use-ipv6=yes
#only allow on public interface
allow-interfaces=${LC_EXTERNAL_DEVICE}
ratelimit-interval-usec=1000000
ratelimit-burst=1000

[wide-area]
enable-wide-area=yes

[publish]
publish-hinfo=no
publish-workstation=no
EOF

### HOSTS
cat - >> ${ROOT_MNT}/etc/hosts << EOF
  ${LC_INTERNAL_IP} ${LC_HOSTNAME}
EOF

### FIRST BOOT CONFIGURATION

cat - >> ${ROOT_MNT}/usr/local/bin/finalize-cloud-init.sh << EOF
#!/bin/sh

BOOT_MNT_LOCAL=/mnt/boot
ROOT_MNT_LOCAL=/mnt/root

#PREVENT PI DEFAULT ACCOUNT LOGIN
usermod pi -s /sbin/nologin

#SSH KEYS
ssh-keygen -q -f /home/${LC_DEFAULT_USER}/.ssh/id_ed25519 -N "" -t ed25519
cat /home/${LC_DEFAULT_USER}/.ssh/id_ed25519.pub >> /home/${LC_DEFAULT_USER}/.ssh/authorized_keys
chown -R ${LC_DEFAULT_USER}:${LC_DEFAULT_USER} /home/${LC_DEFAULT_USER}/.ssh/

for AGENT in \$(cd ${CONFIG_DIR}; ls -d *)
do
  ### COPY AGENT KEYS FOR K3S
  mkdir -p ${CONFIG_DIR}/\${AGENT}${SSH_DIR}/
  rsync -xa --progress /home/${LC_DEFAULT_USER}/.ssh/id_ed25519 ${CONFIG_DIR}/\${AGENT}${SSH_DIR}
  rsync -xa --progress /home/${LC_DEFAULT_USER}/.ssh/id_ed25519.pub ${CONFIG_DIR}/\${AGENT}${SSH_DIR}
  cat /home/${LC_DEFAULT_USER}/.ssh/id_ed25519.pub > ${CONFIG_DIR}/\${AGENT}${SSH_DIR}/authorized_keys
done

#K3S
cd /tmp && curl -sLS https://get.k3sup.dev | sh
# https://github.com/k3s-io/k3s/issues/535#issuecomment-863188327
k3sup install --ip ${LC_INTERNAL_IP} --user ${LC_DEFAULT_USER} --ssh-key "/home/${LC_DEFAULT_USER}/.ssh/id_ed25519" --k3s-extra-args "--node-external-ip=${LC_EXTERNAL_IP} --flannel-iface='${LC_INTERNAL_DEVICE}' --kube-apiserver-arg 'service-node-port-range=1000-32767'"

mkdir -p /root/.kube
rsync -xa --progress ./kubeconfig /root/.kube/config

#READY
wall "BUFFY WILL PATROL TONIGHT"
EOF
chmod a+x ${ROOT_MNT}/usr/local/bin/finalize-cloud-init.sh  

### AGENT CONFIG
mkdir -p ${ROOT_MNT}${CONFIG_DIR}

#CREATE TFTPBOOT DIRECTORY
mkdir -p ${ROOT_MNT}/tftpboot

umount ${ROOT_MNT}

}



