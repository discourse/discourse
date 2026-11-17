#!/usr/bin/env bash
# Signs the agent CLIs in once and saves the result as the image each workspace starts from.
#   start   boots a container from the base image and prints the sign-in commands to run
#   finish  checks both sign-ins, then commits the container as the auth image
set -euo pipefail
source "$(dirname "$0")/docker-lib.sh"

require_docker

base_image="$(setting baseImage)"
auth_image="$(setting authImage)"
auth_name="discourse-orca-env-auth"
project_root="$(setting projectRoot)"

case "${1:-}" in
  start)
    docker image inspect "$base_image" >/dev/null 2>&1 ||
      die "Image $base_image is missing. Run script/orca-vm/docker-base-image.sh first."
    docker rm -f "$auth_name" >/dev/null 2>&1 || true
    docker run -d --name "$auth_name" "$base_image" >/dev/null
    log "Started $auth_name. Sign in to each agent in your own terminal:"
    log ""
    log "  docker exec -it -u discourse -w $project_root $auth_name claude auth login"
    log "  docker exec -it -u discourse -w $project_root $auth_name codex login --device-auth"
    log ""
    log "Then run: script/orca-vm/docker-base-auth.sh finish"
    ;;
  finish)
    container_exists "$auth_name" || die "Container $auth_name is not running. Run start first."
    signed_in=1
    if ! docker exec -u discourse -w "$project_root" "$auth_name" claude auth status >/dev/null 2>&1; then
      log "Claude Code is not signed in."
      signed_in=""
    fi
    if ! docker exec -u discourse -w "$project_root" "$auth_name" codex login status >/dev/null 2>&1; then
      log "Codex is not signed in."
      signed_in=""
    fi
    [ -n "$signed_in" ] || die "Sign in to both agents, then run finish again."

    # Containers made from this image must create their own host keys and Orca identity.
    docker exec "$auth_name" sh -c \
      'rm -rf /etc/ssh/ssh_host_* /home/discourse/.ssh/authorized_keys /home/discourse/.orca-remote /home/discourse/.config/orca'
    docker stop "$auth_name" >/dev/null
    docker commit \
      --change 'ENTRYPOINT ["/usr/local/bin/orca-docker-ssh-entrypoint"]' \
      --change 'CMD []' \
      --change "LABEL $auth_label=true" \
      "$auth_name" "$auth_image" >/dev/null
    docker rm "$auth_name" >/dev/null
    log "Saved $auth_image. Workspaces now start from it."
    docker image inspect -f '{"authImage":"{{index .RepoTags 0}}","imageId":"{{.Id}}"}' "$auth_image"
    ;;
  *)
    die "Usage: $0 start|finish"
    ;;
esac
