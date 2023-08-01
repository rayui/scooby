#!/bin/sh

. ./config
. ./scripts/clone-image.sh
. ./scripts/configure-boot.sh
. ./scripts/configure-root.sh
. ./scripts/configure-agent.sh

VAGRANT=/vagrant
VAGRANT_IMAGE=${VAGRANT}/images/scooby.img
AGENT_DIR=${VAGRANT}/agents

LOOP_DEV=/dev/loop0
LOOP_DEV2=/dev/loop1
BOOT_MNT=/tmp/boot
ROOT_MNT=/tmp/root

SCOOBY_DIR=/var/lib/scooby
SSH_DIR=${SCOOBY_DIR}/ssh
CONFIG_DIR=/etc/scooby/agents
AGENT_BOOT_DIR=/mnt/scooby/boot
AGENT_ROOT_DIR=/mnt/scooby/root

MOUNT_DIR=/mnt/scooby/agents
RANCHERSTORAGEPATH=/var/lib/rancher

cloneBaseImage

losetup -Pf ${VAGRANT_IMAGE}

configureBoot
configureRoot
configureAgents

losetup -D