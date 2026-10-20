#!/bin/bash
set -euo pipefail
/sbin/boot > /tmp/services.log 2>&1 &
mkdir -p /workspace /codex-home
chown discourse:discourse /workspace /workspace/discourse /codex-home
sudo -u discourse git config --global --add safe.directory /seed
if [ ! -d /workspace/discourse/.git ]; then
  sudo -u discourse git clone --depth 1 --branch capybara --no-local file:///seed /workspace/discourse
  sudo -u discourse git -C /workspace/discourse switch -c "bot/card-${CARD_ID}"
  sudo -u discourse git -C /workspace/discourse rev-parse HEAD > /workspace/base.txt
fi
if [ ! -e /workspace/discourse/node_modules ]; then
  cp -a /opt/template/node_modules /workspace/discourse/node_modules
  chown -R discourse:discourse /workspace/discourse/node_modules
fi
sudo -u discourse git -C /workspace/discourse config user.name 'Codex board bot'
sudo -u discourse git -C /workspace/discourse config user.email 'codex-bot@localhost.invalid'
sudo -u discourse git -C /workspace/discourse config core.hooksPath /dev/null
printf 'ready\n' > /tmp/bot-ready
exec sleep infinity
