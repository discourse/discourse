#!/bin/bash
set -euo pipefail
export HOME=/home/discourse CODEX_HOME=/codex-home
export PGUSER=discourse RAILS_ENV=development CI=1
cd /workspace/discourse
for i in $(seq 1 180); do
  test -f /tmp/bot-ready && pg_isready -q && break
  sleep 2
done
test -f /tmp/bot-ready
pg_isready -q
sudo -u discourse -E bundle install --jobs 4
sudo -u discourse -E pnpm install --frozen-lockfile
sudo -u discourse -E bin/rake db:create db:migrate
sudo -u discourse -E bin/rails runner /opt/bot/seed.rb
sudo -u discourse -E env RAILS_ENV=test bin/rake db:create db:migrate
cp /run/codex-auth.json /codex-home/auth.json
chown -R discourse:discourse /codex-home
chmod 700 /codex-home
chmod 600 /codex-home/auth.json
preserve_auth() {
  if [ -f /codex-home/auth.json ]; then
    cp /codex-home/auth.json /run/refreshed-auth.json
    chmod 600 /run/refreshed-auth.json
  fi
  rm -f /codex-home/auth.json /run/codex-auth.json
}
trap preserve_auth EXIT
task_base_commit=$(sudo -u discourse git rev-parse HEAD)
image_args=()
for image in /run/card-images/*; do
  if test -f "$image"; then
    if [[ "$image" == *.gif ]]; then
      convert "${image}[0]" "${image%.gif}.png"
      image="${image%.gif}.png"
    fi
    image_args+=(--image "$image")
  fi
done
sudo -u discourse -E timeout --signal=TERM --kill-after=30s 2700 codex exec "${image_args[@]}" --sandbox danger-full-access --json --output-schema /opt/bot/result-schema.json --output-last-message /workspace/result.json - < /run/prompt.txt > /workspace/codex.jsonl 2> /workspace/codex.stderr
python3 - <<'PY'
import json
result=json.load(open('/workspace/result.json'))
if not result['ready']: raise SystemExit('Codex reported that the change is not ready: '+result['summary'])
PY
sudo -u discourse git add --all
sudo -u discourse -E python3 /opt/bot/lint.py "$task_base_commit"
sudo -u discourse -E bin/rake db:migrate
sudo -u discourse git add --all
if ! sudo -u discourse git diff --cached --quiet; then
  sudo -u discourse git commit -m "Implement card ${CARD_ID}"
fi
sudo -u discourse git rev-parse HEAD > /workspace/commit.txt
