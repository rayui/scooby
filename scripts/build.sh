#!/bin/sh

VARS="./.env"

#load local variables if available
[ -f "${VARS}" ] && . ${VARS}

printf "BRING UP VIRTUAL BUILD HOST\n"
vagrant box update
vagrant plugin install vagrant-vbguest
vagrant up

printf "CREATE BASE IMAGE\n"
vagrant ssh -c "cd /vagrant && sudo --preserve-env=LC_DEFAULT_USER,LC_SSH_AUTH_KEY,LC_PACKER_GITHUB_API_TOKEN ./scripts/create-image.sh"

printf "CREATE SERVER IMAGE\n"
vagrant ssh -c "cd /vagrant && sudo --preserve-env=LC_EXTERNAL_IP,LC_EXTERNAL_NET,LC_EXTERNAL_GW,LC_EXTERNAL_DOMAIN,LC_PRIMARY_DNS,LC_EXTERNAL_DEVICE,LC_HOSTNAME,LC_INTERNAL_DEVICE,LC_INTERNAL_IP,LC_INTERNAL_NET,LC_INTERNAL_DOMAIN,LC_SECONDARY_DNS ./scripts/configure-image.sh"

printf "DESTROY VIRTUAL BUILD HOST\n"
vagrant destroy --force --no-tty