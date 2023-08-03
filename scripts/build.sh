#!/bin/sh

VARS="./.env"

#load local variables if available
[ -f "${VARS}" ] && . ${VARS}

vagrant box update
vagrant plugin install vagrant-vbguest
vagrant up
vagrant ssh -c \
"
cd /vagrant
sudo --preserve-env=\
LC_DEFAULT_USER,\
LC_SSH_AUTH_KEY,\
LC_PACKER_GITHUB_API_TOKEN\
 ./scripts/create-image.sh
sudo --preserve-env=\
LC_HOSTNAME,\
LC_PRIMARY_DNS,\
LC_SECONDARY_DNS,\
LC_EXTERNAL_DEVICE,\
LC_EXTERNAL_IP,\
LC_EXTERNAL_NET,\
LC_EXTERNAL_GW,\
LC_EXTERNAL_DOMAIN,\
LC_INTERNAL_DEVICE,\
LC_INTERNAL_IP,\
LC_INTERNAL_NET,\
LC_INTERNAL_DOMAIN\
 ./scripts/configure-image.sh
"

vagrant destroy --force --no-tty