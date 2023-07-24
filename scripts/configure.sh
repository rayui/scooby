MASTER_HOSTNAME=buffy
VAGRANT=/vagrant
LOOP_DEV=/dev/loop0

. ./scripts/configure-boot.sh
. ./scripts/configure-root.sh
. ./scripts/configure-agent.sh

losetup -Pf ${VAGRANT}/images/scooby.img

configureBoot
configureRoot
configureAgents

losetup -D