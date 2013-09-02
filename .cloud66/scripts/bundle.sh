#!/bin/bash
source /var/.cloud66_env
cd $RAILS_STACK_PATH
su - postgres && psql -d discourse_prod < pg_dumps/production-image.sql && exit
bundle exec rake db:test:prepare db:seed_fu