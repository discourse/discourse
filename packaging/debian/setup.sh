#!/bin/sh
# This script sets up the required config files before buildpack compilation.
#
# It also launches a postgresql server and a redis server, otherwise some rake
# tasks can't be completed.

set -e

# Not everyone chooses to run discourse behind Apache or Nginx.
cat >> config/environments/production.rb <<EOF
Discourse::Application.configure do
  config.serve_static_assets = true
end
EOF

sudo service postgresql start
sudo service redis-server start
