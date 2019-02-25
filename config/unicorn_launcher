#!/bin/bash

# This is a helper script you can use to supervise unicorn, it allows you to perform a live restart
# by sending it a USR2 signal

LOCAL_WEB="http://127.0.0.1:3000/"

function log()
{
  echo "($$) $1"
}

function on_exit()
{
  kill $UNICORN_PID
  log "exiting"
}

function on_reload()
{
  log "Stopping Sidekiq"
  kill -s TSTP $UNICORN_PID
  log "Reloading unicorn ($UNICORN_PID)"
  kill -s USR2 $UNICORN_PID
  unset NEW_UNICORN_PID

  count=0
  while [ "$count" -lt 180 -a -z "$NEW_UNICORN_PID" ]; do
    NEW_UNICORN_PID=`ps -f --ppid $UNICORN_PID | grep 'unicorn master' | grep -v old | grep -v worker | awk '{ print $2 }'`
    log "Waiting for new unicorn master pid... $NEW_UNICORN_PID"
    count=$((count+1))
    sleep 1
  done

  if [ -n "$NEW_UNICORN_PID" ]; then
    count=0
    while [ "$count" -lt 180 -a -z "$(ps -f --ppid $NEW_UNICORN_PID | grep worker | head -1 | awk '{ print $2 }')" ]; do
      log "Waiting for new unicorn workers under $NEW_UNICORN_PID to start up..."
      count=$((count+1))
      sleep 1
    done

    curl $LOCAL_WEB &> /dev/null
    kill -s QUIT $UNICORN_PID
    log "Old pid is: $UNICORN_PID New pid is: $NEW_UNICORN_PID"
    UNICORN_PID=$NEW_UNICORN_PID
  else
    log "Unicorn is taking too long to reload...Sending TERM to $UNICORN_PID"
    kill -s TERM $UNICORN_PID
  fi
}

function on_reopenlogs()
{

  log "Reopening logs"
  kill -s USR1 $UNICORN_PID
}

export UNICORN_SUPERVISOR_PID=$$

trap on_exit EXIT
trap on_reload USR2 HUP
trap on_reopenlogs USR1

unicorn $@ &
UNICORN_PID=$!

echo "supervisor pid: $UNICORN_SUPERVISOR_PID unicorn pid: $UNICORN_PID"

while kill -0 $UNICORN_PID
do
  sleep 1
done
