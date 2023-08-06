. $(pwd)/scripts/defaults

CONFIG=$(pwd)/config
[ -f "${CONFIG}" ] && . ${CONFIG}

cat << EOF
________  ________  ________  ________  ________     ___    ___ 
|\   ____\|\   ____\|\   __  \|\   __  \|\   __  \  |\  \  /  /|
\ \  \____\ \  \___|\ \  \|\  \ \  \|\  \ \  \|\ /_ \ \  \/  / /
 \ \_____  \ \  \    \ \  \ \  \ \  \ \  \ \   __  \ \ \    / / 
  \|____|\  \ \  \____\ \  \_\  \ \  \_\  \ \  \_\  \ \/   / /  
    ____\_\  \ \_______\ \_______\ \_______\ \_______\/   / /    
   |\_________\|_______|\|_______|\|_______|\|_____|\____/ /     
   \|_________|                                    \|____|/      

Using the following server config

LC_HOSTNAME=${LC_HOSTNAME}
LC_PRIMARY_DNS=${LC_PRIMARY_DNS}
LC_SECONDARY_DNS=${LC_SECONDARY_DNS}
LC_EXTERNAL_DEVICE=${LC_EXTERNAL_DEVICE}
LC_EXTERNAL_IP=${LC_EXTERNAL_IP}
LC_EXTERNAL_NET=${LC_EXTERNAL_NET}
LC_EXTERNAL_DOMAIN=${LC_EXTERNAL_DOMAIN}
LC_EXTERNAL_GW=${LC_EXTERNAL_GW}
LC_INTERNAL_IP=${LC_INTERNAL_IP}
LC_INTERNAL_NET=${LC_INTERNAL_NET}
LC_INTERNAL_DEVICE=${LC_INTERNAL_DEVICE}
LC_INTERNAL_DOMAIN=${LC_INTERNAL_DOMAIN}
LC_IMAGE_HREF=${LC_IMAGE_HREF}
LC_IMAGE_SHA=${LC_IMAGE_SHA}
EOF

AGENT_DIR=$(pwd)/agents
if [ -d ${AGENT_DIR} ] && ls ${AGENT_DIR}/*.agent 1> /dev/null 2>&1; then
  for FILE in $(cd ${AGENT_DIR}; ls *.agent)
  do
    printf "\n${FILE}\n"
    cat ${AGENT_DIR}/${FILE}
    printf "\n"
  done
fi