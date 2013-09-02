#!/bin/bash
source /var/.cloud66_env
cd $RAILS_STACK_PATH
psql -d discourse_prod < pg_dumps/production-image.sql
bundle exec rake db:test:prepare db:seed_fu