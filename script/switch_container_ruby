#!/bin/bash

#use this command to switch the running version of Ruby
set -e

old_pwd=`pwd`

if [[ -z "$1" || ( ! -z "$2" && ! -f "$2" ) ]]; then
  echo "Usage: switch_container_ruby VERSION PATCH_FILE"
  exit 1;
fi

if [ ! -f /VERSION  ]; then
  echo "Script is intended to be executed from inside the official docker container only!"
  exit 1;
fi


sv stop unicorn

cd /src

git clone https://github.com/sstephenson/ruby-build.git
cd /src/ruby-build
./install.sh
cd /
rm -rf /src/ruby-build

rm -f /usr/local/bin/rake
rm -f /usr/local/bin/ruby
rm -f /usr/local/bin/ri
rm -f /usr/local/bin/rdoc
rm -f /usr/local/bin/gem
rm -f /usr/local/bin/erb
rm -f /usr/local/bin/bundle
rm -f /usr/local/bin/bundler

if [[ -z "$2" ]]; then
  ruby-build $1 /usr/local
else
  cd $old_pwd
  (ruby-build $1 /usr/local -p < $2)
fi

gem update --system
gem install bundler --force
cd /var/www/discourse

su discourse -c 'bundle install --deployment --verbose --without test --without development --retry 3 --jobs 4'

sv start unicorn
cd $pwd
