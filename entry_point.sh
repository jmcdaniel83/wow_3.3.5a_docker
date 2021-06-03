#!/bin/bash

# ------------------------------------------------------------------------------
# Starts our Server Instance, once the Ctrl+C has been sent to the container
# the server will shutdown.
# ------------------------------------------------------------------------------

# USE the trap if you need to also do manual cleanup after the service is stopped,
#     or need to start multiple services in the one container
trap "echo shutting down..." HUP INT QUIT TERM

# directory structure
BASE_DIR=/opt/wow
CONF_DIR=${BASE_DIR}/conf
SERVER_DIR=${BASE_DIR}/server
LOG_DIR=${SERVER_DIR}/log
DATA_DIR=${SERVER_DIR}/data
SERVER_BIN_DIR=${SERVER_DIR}/bin

# database properties
DB_HOST=wow-sql
DB_PORT=3306
DB_USER=trinity
DB_PASS=trinity
DB_NAME=world

# test query
DB_QUERY="USE $DB_NAME; select * from version LIMIT 1"

# ==============================================================================
# Logging Functions
# ==============================================================================
readonly SCRIPT_NAME=$(basename $0)

function info {
   echo "[INFO ] $@"
   logger -p user.notice -t $SCRIPT_NAME "$@"
}

function error {
   echo "[ERROR] $@"
   logger -p user.error -t $SCRIPT_NAME "$@"
}

function warn {
   echo "[WARN ] $@"
   logger -p user.error -t $SCRIPT_NAME "$@"
}

# ==============================================================================
# Utilities Functions
# ==============================================================================

function db_exists {
   mysql \
      --host=$DB_HOST \
      --port=$DB_PORT \
      --user=$DB_USER \
      --password=$DB_PASS \
      -e "${DB_QUERY}"
}

function wait_for_db {
   while ! true; do
      warn "waiting for database..."
      sleep 5
   done
}

# function wait_for_db {
#    while ! db_exists; do
#       warn "waiting for database..."
#       sleep 5
#    done
# }

function start_screen {
   ## provides a <ctrl+c> <enter> to the screen
   screen -dmS $1 $2
}

function stop_screen {
   ## provides a <ctrl+c> <enter> to the screen
   screen -S $1 -X stuff $'\003\015'
}

function start_server {
   # run our screens for the server
   info "starting authentication server..."
   start_screen auth_server ${SERVER_BIN_DIR}/authserver
   info "authentication server started."

   info "starting world server..."
   start_screen world_server ${SERVER_BIN_DIR}/worldserver
   info "world server started."
}

function stop_server {
   ## provides a <ctrl+c> <enter> to the screens
   info "stopping world server..."
   stop_screen world_server
   info "world server stopped."

   info "stopping authentication server..."
   stop_screen auth_server
   info "authentication server stopped."
}

# ==============================================================================
# Main
# ==============================================================================

if [ "$1" = 'server' ]; then
   wait_for_db
   start_server

   # watch the logs that are generated
   tail -F ${LOG_DIR}/*.log

   stop_server
else
   exec "$@"
fi

# EOF
