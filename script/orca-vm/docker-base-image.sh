#!/usr/bin/env bash
# Builds the base image: the Discourse dev image plus sshd, the agent CLIs, and a ready checkout.
set -euo pipefail
source "$(dirname "$0")/docker-lib.sh"

require_docker

base_image="$(setting baseImage)"
system_image="${base_image%%:*}:system"
build_name="discourse-orca-env-build"

log "Building $system_image."
docker build --pull -t "$system_image" "$orca_vm_dir/docker" >&2

docker rm -f "$build_name" >/dev/null 2>&1 || true
trap 'docker rm -f "$build_name" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$build_name" "$system_image" >/dev/null

log "Cloning $(setting repoUrl) and installing dependencies. This takes a while."
docker exec -u discourse -w /home/discourse "$build_name" \
  /usr/local/bin/orca-discourse-bootstrap "$(setting repoUrl)" "$(setting repoRef)" "$(setting projectRoot)" >&2

# Containers made from this image must create their own host keys.
docker exec "$build_name" sh -c 'rm -f /etc/ssh/ssh_host_* /home/discourse/.ssh/authorized_keys'
docker stop "$build_name" >/dev/null
docker commit \
  --change 'ENTRYPOINT ["/usr/local/bin/orca-docker-ssh-entrypoint"]' \
  --change 'CMD []' \
  "$build_name" "$base_image" >/dev/null

log "Built $base_image. Next, run script/orca-vm/docker-base-auth.sh start."
docker image inspect -f '{"baseImage":"{{index .RepoTags 0}}","imageId":"{{.Id}}"}' "$base_image"
