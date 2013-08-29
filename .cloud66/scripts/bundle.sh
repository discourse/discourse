#!/bin/bash
source /var/.cloud66_env
cd $RAILS_STACK_PATH
bundle exec rake db:seed_fu