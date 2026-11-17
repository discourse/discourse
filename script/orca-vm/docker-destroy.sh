#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/docker-lib.sh"

payload="$(cat)"
name="$(json_get "$payload" recipeResult.userData.resourceId)"
if [ -z "$name" ]; then
  # A create that never returned has no result, so find the container from the instance id.
  instance_id="$(json_get "$payload" instanceId)"
  name="$(container_name_for "${instance_id:-${ORCA_VM_INSTANCE_ID:-}}")"
fi

require_docker
if ! container_exists "$name"; then
  log "Container $name is already gone."
  exit 0
fi

port="$(container_ssh_port "$name")"
port="${port:-$(json_get "$payload" recipeResult.userData.port)}"
host_key="$(json_get "$payload" recipeResult.userData.hostKey)"
host_key="${host_key:-$(container_host_key "$name")}"
docker rm -f "$name" >/dev/null
if [ -n "$port" ] && [ -n "$host_key" ]; then
  forget_host_key "$port" "$host_key"
fi
