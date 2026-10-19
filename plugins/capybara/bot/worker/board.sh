#!/bin/bash
set -euo pipefail
export HOME=/home/discourse PGUSER=discourse RAILS_ENV=development CI=1
/sbin/boot > /tmp/services.log 2>&1 &
mkdir -p /workspace/discourse
chown discourse:discourse /workspace /workspace/discourse
sudo -u discourse git config --global --add safe.directory /seed
until pg_isready -q; do sleep 1; done
cd /workspace/discourse
rm -f /workspace/board-ready
chown discourse:discourse public public/uploads
if [ ! -d .git ]; then
  sudo -u discourse git init .
  sudo -u discourse git remote add origin file:///seed
fi
sudo -u discourse git fetch origin "$BOARD_COMMIT"
sudo -u discourse git reset --hard "$BOARD_COMMIT"
if [ ! -e node_modules ]; then
  cp -a /opt/template/node_modules node_modules
  chown -R discourse:discourse node_modules
fi
if [ ! -f /shared/postgres_data/.capybara-imported ]; then
  test -s /bootstrap/board.dump
  sudo -u postgres dropdb --if-exists discourse_development
  sudo -u postgres createdb --owner discourse discourse_development
  sudo -u postgres psql discourse_development -c 'CREATE EXTENSION IF NOT EXISTS hstore; CREATE EXTENSION IF NOT EXISTS pg_trgm; CREATE EXTENSION IF NOT EXISTS vector;'
  sudo -u postgres pg_restore --list /bootstrap/board.dump > /tmp/restore.list
  python3 -c 'from pathlib import Path; p=Path("/tmp/restore.list"); p.write_text("".join(x for x in p.read_text().splitlines(True) if " EXTENSION " not in x))'
  sudo -u postgres pg_restore --no-owner --no-acl --role discourse --use-list /tmp/restore.list -d discourse_development /bootstrap/board.dump
  cp -a /bootstrap/uploads/. public/uploads/
  chown -R discourse:discourse public/uploads
  touch /shared/postgres_data/.capybara-imported
fi
sudo -u discourse -E bundle install --jobs 4
sudo -u discourse -E pnpm install --frozen-lockfile
sudo -u discourse -E bin/rake db:migrate
rm -f frontend/discourse/dist/manifest/build.json
unset CI
setsid sudo -u discourse -E pnpm --dir frontend/discourse start > /workspace/frontend.log 2>&1 &
setsid sudo -u discourse -E bin/pitchfork -x > /workspace/server.log 2>&1 &
python3 /opt/bot/wait-preview.py
printf '%s\n' "$BOARD_COMMIT" > /workspace/board-ready
exec sleep infinity
