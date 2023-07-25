#!/bin/sh

VAGRANT=/vagrant
IMAGEPATH=${VAGRANT}/images/scooby.img

set -e

export PACKER_GITHUB_API_TOKEN=${LC_PACKER_GITHUB_API_TOKEN}

apt install -y rsync 

packer init packer/
packer build \
  -var "ssh_auth_key=${LC_SSH_AUTH_KEY}" \
  -var "image_href=${LC_IMAGE_HREF}" \
  -var "image_sha=${LC_IMAGE_SHA}" \
  -var "default_user=${LC_DEFAULT_USER}" \
  -var "external_device=${LC_EXTERNAL_DEVICE}" \
  -parallel-builds=1 packer/

  #MAKE BOOTABLE
  sfdisk -A -N 1 ${IMAGEPATH}