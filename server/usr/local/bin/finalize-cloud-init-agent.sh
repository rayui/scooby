#!/bin/sh

SSH_PATH=/var/lib/scooby/ssh
DEFAULT_USER=spike
SERVER_IP=192.168.64.1
AGENT_IP=$(hostname -I)
HOSTNAME=$(hostname)

cp ${SSH_PATH}/* /home/${DEFAULT_USER}/.ssh/

cd /tmp && curl -sLS https://get.k3sup.dev | sh
k3sup join \
--ip ${AGENT_IP} \
--server-ip ${SERVER_IP} \
--user ${DEFAULT_USER} \
--server-user ${DEFAULT_USER} \
--ssh-key "${SSH_PATH}/id_ed25519" \
--k3s-extra-args "--node-name '${HOSTNAME}' --node-label 'smarter-device-manager=enabled'"

wall "${HOSTNAME} IS ONLINE"