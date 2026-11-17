#!/bin/bash
# Runs once inside the base-image build container, as the discourse user.
set -euo pipefail

repo_url="$1"
repo_ref="$2"
project_root="$3"

export GIT_TERMINAL_PROMPT=0

until psql -d discourse_development -c "select 1" >/dev/null 2>&1; do
  sleep 1
done

git clone --branch "$repo_ref" "$repo_url" "$project_root"
cd "$project_root"

bundle install
pnpm install
pnpm playwright-install
sudo pnpm exec playwright install-deps chromium

SKIP_MULTISITE=1 SKIP_TEST_DATABASE=1 bin/rake db:create db:migrate
RAILS_ENV="test" bin/rake db:create db:migrate
