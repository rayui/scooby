#!/bin/sh

SSH_PATH=/var/lib/scooby/ssh
AGENT_IP=$(hostname -I)
HOSTNAME=$(hostname)

#source env vars in sh
. /etc/scooby/.env

cp ${SSH_PATH}/* /home/${LC_DEFAULT_USER}/.ssh/

cd /tmp && curl -sLS https://get.k3sup.dev | sh
k3sup join \
--ip ${AGENT_IP} \
--server-ip ${LC_INTERNAL_IP} \
--user ${LC_DEFAULT_USER} \
--server-user ${LC_DEFAULT_USER} \
--ssh-key "${SSH_PATH}/id_ed25519" \
--k3s-extra-args "--node-name '${HOSTNAME}' --node-label 'smarter-device-manager=enabled'"

wall "${HOSTNAME} IS ONLINE"