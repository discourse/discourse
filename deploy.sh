#!/bin/bash

export RAILS_ENV=production
echo "$(tput setaf 2) Fetching data from git$(tput sgr 0)"
git pull origin master
echo "$(tput setaf 2) Installing gems$(tput sgr 0)"
bundle install
rake db:migrate
rake assets:precompile
echo "$(tput setaf 2) Restarting unicorn server$(tput sgr 0)"
sv restart unicorn
