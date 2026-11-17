#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/docker-lib.sh"

payload="$(cat)"
name="$(json_get "$payload" recipeResult.userData.resourceId)"
[ -n "$name" ] || die "No resource id in the lifecycle payload."

require_docker
docker stop "$name" >/dev/null
