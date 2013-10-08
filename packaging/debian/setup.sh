#!/bin/sh
# This script installs the required example config files before buildpack compilation.

set -ex

cp config/database.yml.production-sample config/database.yml
cp config/redis.yml.sample config/redis.yml
cp config/environments/production.rb.sample config/environments/production.rb
