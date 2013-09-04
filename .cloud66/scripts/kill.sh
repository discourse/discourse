#!/bin/bash
cd $RAILS_STACK_PATH
bundle exec rake kill:kill_postgres_connections
bundle exec rake db:create