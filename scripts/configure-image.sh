#!/bin/sh

. ./scripts/defaults
. ./scripts/resize-image.sh
. ./scripts/configure-boot.sh
. ./scripts/configure-root.sh
. ./scripts/configure-agent.sh

CONFIG=./config
[ -f "${CONFIG}" ] && . ${CONFIG}

VAGRANT=/vagrant
VAGRANT_IMAGE=${VAGRANT}/images/scooby.img
SERVER_DIR=${VAGRANT}/server
AGENT_DIR=${VAGRANT}/agents

LOOP_DEV=/dev/loop0
BOOT_MNT=/tmp/boot
ROOT_MNT=/tmp/root

SCOOBY_DIR=/var/lib/scooby
BASE_DIR=${SCOOBY_DIR}/base
SSH_DIR=${SCOOBY_DIR}/ssh
CONFIG_DIR=/etc/scooby/agents
MOUNT_DIR=/mnt/scooby/agents

resizeImage

losetup -Pf ${VAGRANT_IMAGE}

createAgentBase
configureBoot
configureRoot
configureAgents

losetup -D