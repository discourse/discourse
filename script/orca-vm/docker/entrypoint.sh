#!/bin/bash
set -euo pipefail

# Each container gets its own host keys on first start and keeps them across restarts.
if ! ls /etc/ssh/ssh_host_*_key >/dev/null 2>&1; then
  ssh-keygen -A
fi

if [ -n "${ORCA_SSH_PUBLIC_KEY:-}" ]; then
  install -d -m 700 -o discourse -g discourse /home/discourse/.ssh
  printf '%s\n' "$ORCA_SSH_PUBLIC_KEY" >/home/discourse/.ssh/authorized_keys
  chown discourse:discourse /home/discourse/.ssh/authorized_keys
  chmod 600 /home/discourse/.ssh/authorized_keys
fi

exec /sbin/boot
