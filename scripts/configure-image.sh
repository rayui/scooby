#!/bin/sh

. ./scripts/resize-image.sh
. ./scripts/configure-boot.sh
. ./scripts/configure-root.sh
. ./scripts/configure-agent.sh

VAGRANT=/vagrant
VAGRANT_IMAGE=${VAGRANT}/images/scooby.img

LOOP_DEV=/dev/loop0
LOOP_DEV2=/dev/loop1
BOOT_MNT=/tmp/boot
ROOT_MNT=/tmp/root

SCOOBY_DIR=/var/lib/scooby
BASE_DIR=${SCOOBY_DIR}/base
SSH_DIR=${SCOOBY_DIR}/ssh
CONFIG_DIR=/etc/scooby/agents
MOUNT_DIR=/mnt/scooby/agents

resizeImage

losetup -Pf ${VAGRANT_IMAGE}

configureBoot
configureRoot
importAgentImage
configureAgents

losetup -D