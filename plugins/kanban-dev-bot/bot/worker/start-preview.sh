#!/bin/bash
set -euo pipefail
export HOME=/home/discourse PGUSER=discourse RAILS_ENV=development
export DISCOURSE_SKIP_JS_WATCHERS=1 DISCOURSE_SKIP_CSS_WATCHER=1
cd /workspace/discourse
sudo -u discourse -E bin/rails runner /opt/bot/seed.rb
rm -f frontend/discourse/dist/manifest/{build,manifest}.json
sudo -u discourse -E pnpm --dir frontend/discourse build > /workspace/frontend.log 2>&1
sudo -u discourse -E bin/rake assets:precompile:build_plugins >> /workspace/frontend.log 2>&1
python3 /opt/bot/wait-preview.py --static
setsid sudo -u discourse -E bin/pitchfork > /workspace/server.log 2>&1 < /dev/null &
