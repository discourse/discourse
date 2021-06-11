#!/bin/bash
set -e

"$(dirname "$0")/exec" bin/rake db:migrate
RAILS_ENV=test "$(dirname "$0")/exec" bin/rake db:migrate
