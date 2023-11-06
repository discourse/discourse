#!/bin/bash
set -e;

git reset --hard;
git fetch;
LEFTHOOK=0 git checkout $GITHUB_SHA;

# Remove non-core plugins which are in the discourse_test image
rm -rf /var/www/discourse/plugins/* && git -C /var/www/discourse restore .;

rm -fr tmp/test_data;
mkdir -p tmp/test_data/redis;
mkdir tmp/test_data/pg;

bundle install;
yarn install;

redis-server --dir tmp/test_data/redis --daemonize yes;
script/start_test_db.rb;

bundle exec rake db:create;
LOAD_PLUGINS=1 bundle exec rake db:migrate;
