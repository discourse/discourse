#!/bin/bash
source /var/.cloud66_env
sudo chmod 0444 -R /var/.cloud66_env
cd $RAILS_STACK_PATH

bundle exec rake db:drop
bundle exec rake db:create

su - postgres && cd $RAILS_STACK_PATH && psql -d discourse_prod < pg_dumps/production-image.sql && exit
bundle exec rake db:migrate db:test:prepare db:seed_fu