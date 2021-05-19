#!/bin/bash

readonly SCRIPT_NAME=$(basename $0)

log() {
    echo "[INFO] $@"
    logger -p user.notice -t $SCRIPT_NAME "$@"
    #systemd-cat -p info -t $SCRIPT_NAME "$@"
}

err() {
    echo "[ERROR] $@"
    logger -p user.error -t $SCRIPT_NAME "$@"
    #systemd-cat -p error -t $SCRIPT_NAME "$@"
}

log "starting authentication server..."
screen -dmS auth_server /home/wow/server/bin/authserver
sleep 10
log "authentication server started."

log "starting world server..."
screen -dmS world_server /home/wow/server/bin/worldserver
sleep 10
log "world server started."

# EOF
