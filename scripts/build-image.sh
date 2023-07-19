#!/bin/sh

VAGRANT=/vagrant
IMGDIR=${VAGRANT}/images
IMGNAME=scooby.img

set -e

export PACKER_GITHUB_API_TOKEN=${LC_PACKER_GITHUB_API_TOKEN}

apt install -y rsync 

packer init packer/
packer build \
  -var "ssh_auth_key=${LC_SSH_AUTH_KEY}" \
  -var "image_href=${LC_IMAGE_HREF}" \
  -var "image_sha=${LC_IMAGE_SHA}" \
  -var "default_user=${LC_DEFAULT_USER}" \
  -parallel-builds=1 packer/

#MAKE BOOTABLE
sfdisk -A -N 1 ${IMGDIR}/${IMGNAME}