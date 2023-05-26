#!/bin/sh

DEFAULT_USER=spike
SERVER_IP=192.168.64.1
AGENT_IP=$(hostname -I)
HOSTNAME=$(hostname)

cp /var/lib/scooby/ssh/${DEFAULT_USER}_ed25519_key /home/${DEFAULT_USER}/.ssh/id_ed25519
cp /var/lib/scooby/ssh/${DEFAULT_USER}_ed25519_key.pub /home/${DEFAULT_USER}/.ssh/id_ed25519.pub
cat /var/lib/scooby/ssh/${DEFAULT_USER}_ed25519_key.pub >> /home/${DEFAULT_USER}/.ssh/authorized_keys
cd /tmp && curl -sLS https://get.k3sup.dev | sh
k3sup join \
--ip ${AGENT_IP} \
--server-ip ${SERVER_IP} \
--user ${DEFAULT_USER} \
--server-user ${DEFAULT_USER} \
--ssh-key "/var/lib/scooby/ssh/${DEFAULT_USER}_ed25519_key" \
--k3s-extra-args "--node-name '${HOSTNAME}' --node-label 'smarter-device-manager=enabled'"

wall "${HOSTNAME} IS ONLINE"