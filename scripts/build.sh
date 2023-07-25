#!/bin/sh

VARS="./.env"

#load local variables if available
[ -f "${VARS}" ] && . ${VARS}

printf "BRING UP VIRTUAL BUILD HOST\n"
vagrant box update
vagrant plugin install vagrant-vbguest
vagrant up

printf "CREATE BASE IMAGE\n"
vagrant ssh -c "cd /vagrant && sudo --preserve-env=LC_IMAGE_HREF,LC_IMAGE_SHA,LC_DEFAULT_USER,LC_SSH_AUTH_KEY,LC_PACKER_GITHUB_API_TOKEN ./scripts/create-image.sh"
dd if=./images/scooby.img of=./images/scooby-agent.img bs=1M status=progress

printf "CREATE SERVER IMAGE\n"
vagrant ssh -c "cd /vagrant && sudo --preserve-env=LC_EXTERNAL_DEVICE,LC_EXTERNAL_IP,LC_INTERNAL_IP,LC_INTERNAL_DEVICE,LC_DEFAULT_USER ./scripts/configure-image.sh"

printf "DESTROY VIRTUAL BUILD HOST\n"
vagrant destroy --force --no-tty