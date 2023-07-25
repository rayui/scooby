MASTER_HOSTNAME=buffy
VAGRANT=/vagrant
LOOP_DEV=/dev/loop0
IMAGEPATH=${VAGRANT}/images/scooby.img

. ./scripts/resize-image.sh
. ./scripts/configure-boot.sh
. ./scripts/configure-root.sh
. ./scripts/configure-agent.sh

resizeImage

losetup -Pf ${IMAGEPATH}

configureBoot
configureRoot
importAgentImage
configureAgents

losetup -D