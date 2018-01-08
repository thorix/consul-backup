#!/bin/sh
# Description: Backup Hashicorp's Consul data to AWS S3 using snapshots.
# All errors should make the container die. The K8S way, no half working services
# Usage:
#   ./init.sh    # This will start a consul agent and run AWS S3 backups every $SLEEP_DURATION
#   ./init.sh <given file name> # This will assume consul agent is running and restore the file.

# kill 0: nested sub-shells need to be killed as well and script exits should trigger that as well
#trap "exit" INT TERM
#trap "kill 0" EXIT
### trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
cleanup() {
    echo "#$?#"
    # kill 0
    local pids=$(jobs -p)
    echo "${pid}"
    # [ -n "$pids" ] && kill $pids
    echo "#$?#"
}
trap "cleanup" INT QUIT TERM EXIT



# If the user gives an argument then use this as the  name of the file to restore
if [ "$1" != "" ]; then
  RESTORE_FILE=$1
  echo "Restore file given on command line. '$RESTORE_FILE'"

  RESTORE_TIMEOUT=${RESTORE_TIMEOUT:-60}
  echo "Using the wait time for Consul before restore: '${RESTORE_TIMEOUT}' (secs)"
else
  # How long to sleep between backups. Default is 1800secs = 30mins
  SLEEP_DURATION=${SLEEP_DURATION:-60}
  echo "Using Backup sleep duration: '${SLEEP_DURATION}'"
fi




# https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
if [ -z "${S3_URL+x}" ]; then
  echo "Needed variable not set 'S3_URL', exiting"
  exit 1
fi

run_cmd()
{
  CMD=$1
  echo "CMD: '${CMD}'"
  eval "${CMD}"
  return
}

 # This is the main loop that will run forever, or until an error.
backup_loop()
{
  echo "Starting Consul backup service"
  while true; do
    # Create file name
    FILENAME="/consul-$(date -u +%Y%m%d.%H%M%S).snap"
    # Create snapshot
    run_cmd "consul snapshot save \"${FILENAME}\""

    if [ -f "${FILENAME}" ]; then
      #Upload to s3
      run_cmd "aws s3 cp \"${FILENAME}\" \"${S3_URL}\""
      # Remove file
      run_cmd "rm -rf \"${FILENAME}\""
      echo "$(date -u -Iminutes) backup is a success." > /heartBeat.txt
    else
      echo "Error: consul snapshot did not create a file. Looking for '${FILENAME}'"
      exit 1
    fi
      sleep ${SLEEP_DURATION}
  done
}

# This should only run with fresh install of Vault and Consul
restore_snapshot()
{
  echo "Starting the restore process for file '${RESTORE_FILE}'"

  run_cmd "aws s3 cp \"${S3_URL}${RESTORE_FILE}\" ./"
  if [ -f "/${RESTORE_FILE}" ]; then
    run_cmd "consul snapshot restore \"${RESTORE_FILE}\""
    exit 0
  else
    echo "Error: awscli did not download the given snapshot. Looking for '/${RESTORE_FILE}'"
    exit 1
  fi
}

run_consul()
{
  if [ -z "${CONSUL_ARGS}" ]; then
    echo "Needed variable not set 'CONSUL_ARGS', exiting"
    exit 1
  fi

  # Run consul in the background
  mkdir -p /consul/data/
  chown -R consul /consul/data/
  su-exec consul consul agent ${CONSUL_ARGS} &
  sleep 10
}

run_consul

if [ -n "${RESTORE_FILE}" ]; then
  i="0"
  while [ $i -le $((RESTORE_TIMEOUT/5)) ]; do
    echo "Waiting for Consul..."
    if pgrep -f "consul agent"; then
      restore_snapshot
    fi
    sleep 5
    i=$((i+1))
  done
  echo "Error: Consul is not running!"
  exit 1
else
  backup_loop
fi
