#!/bin/bash
set -euo pipefail
bot_root=$(cd "$(dirname "$0")" && pwd)
source_repo=${SEED_HOST_PATH:-/Users/joffreyjaffeux/Code/discourse}
docker_bin=$(command -v docker || true)
docker_bin=${docker_bin:-/Applications/OrbStack.app/Contents/MacOS/xbin/docker}
docker_endpoint=${DOCKER_HOST:-unix:///Users/joffreyjaffeux/.orbstack/run/docker.sock}
docker_args=(--host "$docker_endpoint")
compose_args=(-f "$bot_root/compose.yaml")
case "${1:-status}" in
  build)
    image_context="$bot_root/.build/worker-image"
    mkdir -p "$image_context"
    "$docker_bin" "${docker_args[@]}" run --rm --entrypoint bash \
      --mount "type=bind,source=$bot_root,target=/bot,readonly" \
      --mount "type=bind,source=$source_repo,target=/seed,readonly" \
      --mount "type=bind,source=$image_context,target=/context" \
      discourse/discourse_dev:20260812-0036 -lc '
        set -eu
        rm -rf /context/template /context/worker
        mkdir -p /context/template
        git -c safe.directory=/seed -C /seed archive capybara | tar -x -C /context/template
        cp -a /bot/worker /context/worker
        cp /bot/worker/Dockerfile /context/Dockerfile
      '
    "$docker_bin" "${docker_args[@]}" build -t discourse-codex-worker:local "$image_context"
    "$docker_bin" "${docker_args[@]}" compose "${compose_args[@]}" build
    ;;
  up)
    "$docker_bin" "${docker_args[@]}" compose "${compose_args[@]}" up -d
    ;;
  stop)
    "$docker_bin" "${docker_args[@]}" compose "${compose_args[@]}" stop
    ;;
  logs)
    "$docker_bin" "${docker_args[@]}" compose "${compose_args[@]}" logs --tail 100 -f
    ;;
  status)
    "$docker_bin" "${docker_args[@]}" compose "${compose_args[@]}" ps
    ;;
  refresh-auth)
    "$docker_bin" "${docker_args[@]}" exec discourse-board-controller rm -f /data/codex-auth.json
    "$docker_bin" "${docker_args[@]}" compose "${compose_args[@]}" up -d --force-recreate
    ;;
  export)
    card_id=${2:?Supply the card ID}
    archive_path=${3:?Supply an output archive path}
    [[ "$card_id" =~ ^[0-9]+$ ]] || { echo 'The card ID must be numeric.' >&2; exit 1; }
    test ! -e "$archive_path" || { echo 'The destination already exists.' >&2; exit 1; }
    workspace_volume=$("$docker_bin" "${docker_args[@]}" exec discourse-board-controller python -c 'import json,sqlite3,sys; rows=sqlite3.connect("/data/runs.sqlite3").execute("SELECT payload FROM runs ORDER BY rowid DESC"); print(next(json.loads(r[0])["workspace_volume"] for r in rows if json.loads(r[0])["card_id"]==int(sys.argv[1])))' "$card_id")
    "$docker_bin" "${docker_args[@]}" volume inspect "$workspace_volume" >/dev/null 2>&1 || {
      echo 'The workspace has been reclaimed and is no longer available for export.' >&2
      exit 1
    }
    "$docker_bin" "${docker_args[@]}" run --rm --entrypoint tar \
      --mount "type=volume,source=$workspace_volume,target=/workspace,readonly" \
      discourse-codex-worker:local -C /workspace \
      --exclude=discourse/node_modules --exclude=discourse/tmp --exclude=discourse/log \
      -czf - discourse > "$archive_path"
    ;;
  *)
    echo 'Usage: manage.sh {build|up|stop|logs|status|refresh-auth|export CARD_ID ARCHIVE_PATH}' >&2
    exit 1
    ;;
esac
