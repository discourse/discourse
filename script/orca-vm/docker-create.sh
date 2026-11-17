#!/usr/bin/env bash
# Starts one Discourse dev container for an Orca workspace and prints its SSH connection.
set -euo pipefail
source "$(dirname "$0")/docker-lib.sh"

require_docker
ensure_ssh_key

image="$(setting authImage)"
if [ "$(docker image inspect -f "{{index .Config.Labels \"$auth_label\"}}" "$image" 2>/dev/null)" != "true" ]; then
  die "Image $image is missing or not signed in. Run script/orca-vm/docker-base-image.sh, then script/orca-vm/docker-base-auth.sh start and finish."
fi

name="$(container_name_for "${ORCA_VM_INSTANCE_ID:-}")"
created=""
cleanup() {
  if [ -n "$created" ]; then
    log "Removing $name after a failed create."
    docker rm -f "$name" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if container_exists "$name"; then
  log "Reusing container $name."
  docker start "$name" >/dev/null
else
  run_args=(
    -d --name "$name" --hostname discourse-dev
    --label "org.discourse.orca-env.instance=${ORCA_VM_INSTANCE_ID}"
    -p 127.0.0.1::22
    -e "ORCA_SSH_PUBLIC_KEY=$(cat "$ssh_key.pub")"
  )
  resources="$(orca_resources_dir)"
  if [ -n "$resources" ]; then
    run_args+=(-v "$resources:/opt/orca-app:ro")
  else
    log "Orca.app was not found, so the orca CLI will not work inside the container."
  fi
  created=1
  docker run "${run_args[@]}" "$image" >/dev/null
fi

result="$(connect_and_emit "$name")"
port="$(json_get "$result" userData.port)"
repo_ref="$(setting repoRef)"
log "Updating $(setting projectRoot) to $repo_ref."
container_ssh "$port" "$(printf 'cd %q && GIT_TERMINAL_PROMPT=0 git fetch --quiet origin %q && git checkout --quiet -B %q FETCH_HEAD' \
  "$(setting projectRoot)" "$repo_ref" "$repo_ref")" >&2

created=""
printf '%s\n' "$result"
