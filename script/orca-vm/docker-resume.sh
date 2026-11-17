#!/usr/bin/env bash
# Docker can publish a different port after a restart, so this prints a fresh connection.
set -euo pipefail
source "$(dirname "$0")/docker-lib.sh"

payload="$(cat)"
name="$(json_get "$payload" recipeResult.userData.resourceId)"
[ -n "$name" ] || die "No resource id in the lifecycle payload."

require_docker
old_port="$(json_get "$payload" recipeResult.userData.port)"
old_key="$(json_get "$payload" recipeResult.userData.hostKey)"
docker start "$name" >/dev/null
result="$(connect_and_emit "$name")"
if [ -n "$old_port" ] && [ "$old_port" != "$(json_get "$result" userData.port)" ]; then
  forget_host_key "$old_port" "$old_key"
fi
printf '%s\n' "$result"
