#!/usr/bin/env bash
# Run the nginx spec suite.
#
# Usage:
#   spec/nginx/run.sh [extra rspec args]
#
# We pass --options /dev/null so rspec ignores the project's top-level
# .rspec (which auto-requires rails_helper). The nginx specs are
# deliberately rails-free.

set -euo pipefail

cd "$(dirname "$0")/../.."

exec bundle exec rspec \
  --options /dev/null \
  --require ./spec/nginx/spec_helper.rb \
  --color \
  --format documentation \
  --default-path spec/nginx \
  "$@"
