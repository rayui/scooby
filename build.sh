#!/bin/bash
set -e

export SSH_AUTH_KEY=${LC_SSH_AUTH_KEY}
export PACKER_GITHUB_API_TOKEN=${LC_PACKER_GITHUB_API_TOKEN}

sudo -E echo "SSH_AUTH_KEY=${SSH_AUTH_KEY}"
sudo -E echo "PACKER_GITHUB_API_TOKEN=${PACKER_GITHUB_API_TOKEN}"

sudo -E packer init packer/
sudo -E packer build \
  -var "ssh_auth_key=${SSH_AUTH_KEY}" \
  -parallel-builds=2 packer/