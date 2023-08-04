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
sudo ./scripts/configure-image.sh
"

vagrant destroy --force --no-tty