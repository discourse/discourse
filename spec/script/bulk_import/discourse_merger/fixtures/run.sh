#!/usr/bin/env bash
# Inside a new, network-isolated all-in-one image. Only the test code is mounted.
set -euo pipefail
cd /var/www/discourse
export RAILS_ENV=production DISCOURSE_HOSTNAME=merge.example.test DISCOURSE_DB_HOST=/var/run/postgresql
export DISCOURSE_DISABLE_EMAILS=yes MERGE_FIXTURE=1
pg_bin=$(pg_config --bindir)
install -d -o postgres -g postgres /tmp/member-review-db /shared/postgres_run
install -d -o discourse -g discourse /shared/uploads /shared/log/rails
sudo -u postgres "$pg_bin/initdb" -D /tmp/member-review-db --auth-local=trust >/dev/null
sudo -u postgres "$pg_bin/pg_ctl" -D /tmp/member-review-db -l /tmp/member-review-db/log -w start >/dev/null
redis-server --daemonize yes
for attempt in {1..30}; do
  if redis-cli ping | grep -qx PONG; then break; fi
  sleep 1
done
redis-cli ping | grep -qx PONG
sudo -u postgres createuser -s discourse
sudo -u postgres createdb -O discourse discourse
sudo -u discourse psql -Xq -v ON_ERROR_STOP=1 discourse -f db/structure.sql >/dev/null
sudo -HEu discourse bundle exec rake db:migrate db:seed >/dev/null
# Minimal images can omit the optional bot seed; both forums use the same canonical ID.
sudo -HEu discourse psql -Xq -v ON_ERROR_STOP=1 discourse <<'SQL'
INSERT INTO users (id, username, username_lower, trust_level, created_at, updated_at)
VALUES (-2, 'discobot', 'discobot', 4, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO NOTHING;
SQL
sudo -u postgres createdb -T discourse -O discourse fixture_source
# Supervise the web/worker services in the stopped state used for a real apply.
for service in /etc/service/{unicorn,pitchfork,sidekiq}; do
  if [[ -d "$service" ]]; then
    touch "$service/down"
    runsv "$service" &
    for attempt in {1..50}; do
      if sv status "$service" | grep -q '^down:'; then break; fi
      sleep 0.1
    done
    chgrp discourse "$service/supervise" "$service/supervise/status" "$service/supervise/ok"
    chmod g+x "$service/supervise"
    chmod g+r "$service/supervise/status"
    chmod g+w "$service/supervise/ok"
  fi
done
bash /fixture/project.sh
sudo -u discourse pg_dump -Fc discourse >/tmp/member-review.dump
sudo -u postgres createdb -O discourse fixture_restored
sudo -u discourse pg_restore --single-transaction -d fixture_restored /tmp/member-review.dump
sudo -HEu discourse env DISCOURSE_DB_NAME=fixture_restored FIXTURE_STAGE=verify bundle exec rails runner /fixture/member_review.rb

# Exercise actual image responses and the readiness endpoint on the restored database.
sudo -HEu discourse env DISCOURSE_DB_NAME=fixture_restored bundle exec pitchfork -l 127.0.0.1:8391 > /tmp/fixture-web.log 2>&1 &
web_pid=$!
trap 'kill "$web_pid" 2>/dev/null || true' EXIT
request=(curl --silent --fail --max-time 10 --header "Host: merge.example.test")
for attempt in {1..60}; do
  if "${request[@]}" http://127.0.0.1:8391/srv/status > /dev/null; then break; fi
  if ! kill -0 "$web_pid" 2>/dev/null; then cat /tmp/fixture-web.log; exit 1; fi
  sleep 1
done
"${request[@]}" http://127.0.0.1:8391/srv/status > /dev/null
while IFS= read -r image; do
  "${request[@]}" "http://127.0.0.1:8391$image" > /tmp/fixture-avatar.png
  if cmp -s /tmp/fixture-avatar.png public/images/avatar.png; then echo "Unexpected blank avatar" >&2; exit 1; fi
  identify -quiet /tmp/fixture-avatar.png
done < /tmp/fixture-image-paths
