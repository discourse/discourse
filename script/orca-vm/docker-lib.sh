# shellcheck shell=bash disable=SC2034
# Shared helpers for the docker recipe scripts. Every script keeps stdout for its final JSON.

orca_vm_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
state_file="$orca_vm_dir/docker-state.json"
ssh_key="$orca_vm_dir/.ssh/id_ed25519"
known_hosts="$HOME/.ssh/known_hosts"
auth_label="org.discourse.orca-env.authenticated"

log() {
  printf '%s\n' "$*" >&2
}

die() {
  log "$*"
  exit 1
}

# Reads a value from DISCOURSE_ORCA_<KEY> first, then from the state file.
setting() {
  local key="$1"
  local env_name
  env_name="DISCOURSE_ORCA_$(printf '%s' "$key" | sed 's/\([A-Z]\)/_\1/g' | tr '[:lower:]' '[:upper:]')"
  if [ -n "${!env_name:-}" ]; then
    printf '%s' "${!env_name}"
    return
  fi
  node -e 'const v = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))[process.argv[2]]; if (v == null) process.exit(1); process.stdout.write(String(v))' \
    "$state_file" "$key" || die "Missing \"$key\" in $state_file"
}

# Prints a dotted path from a JSON document, or nothing when it is absent.
json_get() {
  node -e 'let v = JSON.parse(process.argv[1] || "{}"); for (const k of process.argv[2].split(".")) v = v?.[k]; if (v != null) process.stdout.write(String(v))' \
    "$1" "$2"
}

require_docker() {
  command -v docker >/dev/null || die "docker is not on PATH."
  docker info >/dev/null 2>&1 || die "The Docker daemon is not running. Start OrbStack or Docker Desktop."
}

ensure_ssh_key() {
  if [ ! -f "$ssh_key" ]; then
    mkdir -p "$(dirname "$ssh_key")"
    chmod 700 "$(dirname "$ssh_key")"
    ssh-keygen -q -t ed25519 -N "" -C "orca-discourse-docker" -f "$ssh_key" >&2
  fi
}

container_name_for() {
  local id
  id="$(printf '%s' "$1" | tr -c 'a-zA-Z0-9_.-' '-')"
  [ -n "$id" ] || die "No workspace instance id was given."
  printf 'orca-discourse-%s' "$id" | cut -c1-63
}

container_exists() {
  docker container inspect "$1" >/dev/null 2>&1
}

# The Orca CLI is plain JavaScript, so the container runs the desktop's copy from a read-only mount.
orca_resources_dir() {
  local candidates=()
  [ -n "${ORCA_CLI_BIN_DIR:-}" ] && candidates+=("$ORCA_CLI_BIN_DIR/..")
  command -v orca >/dev/null 2>&1 && candidates+=("$(dirname "$(command -v orca)")/..")
  candidates+=("/Applications/Orca.app/Contents/Resources")
  local dir
  for dir in "${candidates[@]}"; do
    if [ -f "$dir/app.asar.unpacked/out/cli/index.js" ]; then
      (cd "$dir" && pwd -P)
      return
    fi
  done
}

container_host_key() {
  docker cp "$1:/etc/ssh/ssh_host_ed25519_key.pub" - 2>/dev/null | tar -xOf - 2>/dev/null | awk '{print $1" "$2}'
}

container_ssh_port() {
  docker port "$1" 22/tcp 2>/dev/null | sed -n 's/^127\.0\.0\.1:\([0-9][0-9]*\)$/\1/p' | head -1
}

forget_host_key() {
  local port="$1"
  local host_key="$2"
  [ -f "$known_hosts" ] || return 0
  if ssh-keygen -F "[127.0.0.1]:$port" -f "$known_hosts" 2>/dev/null | grep -qF "$host_key"; then
    ssh-keygen -R "[127.0.0.1]:$port" -f "$known_hosts" >/dev/null 2>&1
  fi
}

# Trusts the container's host key, read through docker exec, for its published port.
record_host_key() {
  local name="$1"
  local port="$2"
  mkdir -p "$(dirname "$known_hosts")"
  touch "$known_hosts"
  ssh-keygen -R "[127.0.0.1]:$port" -f "$known_hosts" >/dev/null 2>&1 || true
  docker exec "$name" sh -c 'cat /etc/ssh/ssh_host_*_key.pub' |
    awk -v host="[127.0.0.1]:$port" '{print host" "$1" "$2}' >>"$known_hosts"
}

ssh_opts() {
  printf '%s\n' -i "$ssh_key" -p "$1" -o BatchMode=yes -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=yes -o "UserKnownHostsFile=$known_hosts" -o ConnectTimeout=5
}

container_ssh() {
  local port="$1"
  shift
  local opts=()
  while IFS= read -r opt; do opts+=("$opt"); done < <(ssh_opts "$port")
  ssh "${opts[@]}" "$(setting username)@127.0.0.1" "$@"
}

# Waits for sshd, trusts the host key, and prints the recipe result for an existing container.
connect_and_emit() {
  local name="$1"
  local port="" host_key="" attempt

  for attempt in $(seq 1 60); do
    port="$(container_ssh_port "$name")"
    host_key="$(container_host_key "$name")"
    [ -n "$port" ] && [ -n "$host_key" ] && break
    if [ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null)" != "true" ]; then
      docker logs --tail 50 "$name" >&2 || true
      die "Container $name stopped while starting."
    fi
    sleep 1
  done
  if [ -z "$port" ] || [ -z "$host_key" ]; then
    die "Container $name did not publish SSH in time."
  fi

  record_host_key "$name" "$port"

  for attempt in $(seq 1 30); do
    container_ssh "$port" true 2>/dev/null && break
    [ "$attempt" = 30 ] && { container_ssh "$port" true || die "SSH to $name on port $port failed."; }
    sleep 1
  done

  node -e '
    const [name, port, user, identityFile, projectRoot, hostKey] = process.argv.slice(1);
    console.log(JSON.stringify({
      schemaVersion: 1,
      connection: {
        type: "ssh",
        projectRoot,
        target: { label: name, host: "127.0.0.1", port: Number(port), username: user, identityFile, identitiesOnly: true },
      },
      userData: { provider: "docker", resourceId: name, port: Number(port), hostKey },
    }));
  ' "$name" "$port" "$(setting username)" "$ssh_key" "$(setting projectRoot)" "$host_key"
}
