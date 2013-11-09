# Discourse Advanced Developer Install Guide

This guide is aimed at advanced Rails developers who have installed their own Rails apps before. If you are new to Rails, you are likely much better off with our **[Discourse Vagrant Developer Guide](VAGRANT.md)**.

Note: If you are developing on a Mac, you will probably want to look at [these instructions](DEVELOPMENT-OSX-NATIVE.md) as well.

## First Steps

1. Install and configure PostgreSQL 9.1+. Make sure that the server's messages language is English; this is [required](https://github.com/rails/rails/blob/3006c59bc7a50c925f6b744447f1d94533a64241/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb#L1140) by the ActiveRecord Postgres adapter.
2. Install and configure Redis 2+.
3. Install libxml2, g++, and make.
4. Install Ruby 1.9.3 and Bundler.
5. Clone the project and bundle.
6. Copy `config/database.yml.development-sample` to `config/database.yml`. Copy `config/redis.yml.sample` to `config/redis.yml`. Edit the files to point to your postgres and redis instances.
7. Create the "vagrant" user and the development and test databases in postgres. See the postgres section in "Building your own Vagrant VM", below.
8. Install the seed data to set up an admin account and meta topic: `psql DATABASE_NAME < pg_dumps/production-image.sql`


## Before you start Rails

1. `bundle install`
2. `bundle exec rake db:migrate db:test:prepare db:seed_fu`
4. Try running the specs: `bundle exec rake autospec`
5. `bundle exec rails server`

You should now be able to connect to rails on [http://localhost:3000](http://localhost:3000) - try it out! The seed data includes a pinned topic that explains how to get an admin account, so start there! Happy hacking!


# Building your own Vagrant VM

Here are the steps we used to create the **[Vagrant Virtual Machine](VAGRANT.md)**. They might be useful if you plan on setting up an environment from scratch on Linux:


## Base box

Vagrant version 1.1.2. With this Vagrantfile:

    Vagrant::Config.run do |config|
      config.vm.box     = 'precise32'
      config.vm.box_url = 'http://files.vagrantup.com/precise32.box'
      config.vm.network :hostonly, '192.168.10.200'

      if RUBY_PLATFORM =~ /darwin/
        config.vm.share_folder("v-root", "/vagrant", ".", :nfs => true)
      end
    end

    vagrant up
    vagrant ssh

## Some basic setup:

    sudo su -
    ln -sf /usr/share/zoneinfo/Canada/Eastern /etc/localtime
    apt-get -yqq update
    apt-get -yqq install python-software-properties
    apt-get -yqq install vim curl expect debconf-utils git-core build-essential zlib1g-dev libssl-dev openssl libcurl4-openssl-dev libreadline6-dev libpcre3 libpcre3-dev

## Unicode

    echo "export LANGUAGE=en_US.UTF-8" >> /etc/bash.bashrc
    echo "export LANG=en_US.UTF-8" >> /etc/bash.bashrc
    echo "export LC_ALL=en_US.UTF-8" >> /etc/bash.bashrc
    export LANGUAGE=en_US.UTF-8
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8

    locale-gen en_US.UTF-8
    dpkg-reconfigure locales

## RVM and Ruby

    apt-get -yqq install libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison subversion pkg-config curl build-essential git

    su - vagrant -c "sudo bash -s stable < <(curl -s https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer)"
    adduser vagrant rvm
    source /etc/profile.d/rvm.sh
    su - vagrant -c "rvm pkg install libyaml"
    su - vagrant -c "rvm install 2.0.0-turbo"
    su - vagrant -c "rvm use 2.0.0-turbo --default"

    echo "gem: --no-rdoc --no-ri" >> /etc/gemrc
    su - vagrant -c "echo 'gem: --no-rdoc --no-ri' >> ~/.gemrc"

## Postgres 9.1

Configure so that the vagrant user doesn't need to provide username and password.

    apt-get -yqq install postgresql postgresql-contrib-9.1 libpq-dev postgresql-server-dev-9.1
    su - postgres
    createuser --createdb --superuser -Upostgres vagrant
    psql -c "ALTER USER vagrant WITH PASSWORD 'password';"
    psql -c "create database discourse_development owner vagrant encoding 'UTF8' TEMPLATE template0;"
    psql -c "create database discourse_test        owner vagrant encoding 'UTF8' TEMPLATE template0;"
    psql -d discourse_development -c "CREATE EXTENSION hstore;"
    psql -d discourse_development -c "CREATE EXTENSION pg_trgm;"


Edit /etc/postgresql/9.1/main/pg_hba.conf to have this:

    local all all trust
    host all all 127.0.0.1/32 trust
    host all all ::1/128 trust
    host all all 0.0.0.0/0 trust # wide-open

Load the seed data (as vagrant user):

    psql -d discourse_development < pg_dumps/development-image.sql

(You may wish to try the `production-image.sql` file for a good seed for a production database.)

## Redis

    sudo su -
    mkdir /tmp/redis_install
    cd /tmp/redis_install
    wget http://redis.googlecode.com/files/redis-2.6.7.tar.gz
    tar xvf redis-2.6.7.tar.gz
    cd redis-2.6.7
    make
    make install
    cd utils
    ./install_server.sh
    # Press enter to accept all the defaults
    /etc/init.d/redis_6379 start


## Phantomjs

Needed to run javascript tests.

    cd /usr/local/share
    wget https://phantomjs.googlecode.com/files/phantomjs-1.8.2-linux-i686.tar.bz2
    tar xvf phantomjs-1.8.2-linux-i686.tar.bz2
    rm phantomjs-1.8.2-linux-i686.tar.bz2
    ln -s /usr/local/share/phantomjs-1.8.2-linux-i686/bin/phantomjs /usr/local/bin/phantomjs
