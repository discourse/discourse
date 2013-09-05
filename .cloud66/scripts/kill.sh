#!/bin/bash
cd $RAILS_STACK_PATH
bundle exec rake kill_postgres_connections
rake db:drop db:create