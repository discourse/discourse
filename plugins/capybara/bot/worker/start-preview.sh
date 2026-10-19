#!/bin/bash
set -euo pipefail
export HOME=/home/discourse PGUSER=discourse RAILS_ENV=development
cd /workspace/discourse
sudo -u discourse -E bin/rails runner /opt/bot/seed.rb
rm -f frontend/discourse/dist/manifest/build.json
setsid sudo -u discourse -E pnpm --dir frontend/discourse start > /workspace/frontend.log 2>&1 < /dev/null &
setsid sudo -u discourse -E bin/pitchfork > /workspace/server.log 2>&1 < /dev/null &

python3 /opt/bot/wait-preview.py
