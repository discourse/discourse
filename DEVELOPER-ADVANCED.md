# Discourse Advanced Developer Install Guide

This guide is aimed at advanced Rails developers who have installed their own Rails apps before. If you are new
to rails, you are likely much better off with our **[Discourse Advanced Developer Guide](https://github.com/discourse/discourse/blob/master/DEVELOPER-ADVANCED.md)**.
The advanced guide also contains instructions on how to provision your own Vagrant VM.


## First Steps

1. Install and configure PostgreSQL 9.1+
2. Install and configure Redis 2+
3. Install Rails 1.9.3 and Bundler.
3. Clone the project.
4. Create development and test databases in postgres.
5. Copy `config/database.yml.sample' and `config/redis.yml.sample` to `config/database.yml` and `config/redis.yml.sample` and input the correct values to point to your postgres and redis instances.
6. We recommend starting with seed data to play around in your development environment. [Download Seed SQL Data](http://discourse.org/vms/dev-discourse-seed.sql). Install it into postgres using a command like this: `psql -d discourse_development < dev-discourse-seed.sql`.


## Before you start Rails

1. `bundle install`
2. `rake db:migrate`
3. `rake db:test:prepare`
4. Try running the specs: `bundle exec rspec`
5. `bundle exec rails server`

You should now be able to connect to rails on http://localhost:3000 - try it out! The seed data includes a pinned topic that explains how to get an admin account, so start there! Happy hacking!


# Provisioning a Vagrant VM:

Here are the steps we used to create the **[Vagrant Virtual Machine](https://github.com/discourse/discourse/blob/master/VAGRANT.md)**. They might be useful if you plan on setting up an environment from scratch on Linux:


## Base box

Vagrant version 1.0.5. With this Vagrantfile:

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
    su - vagrant -c "rvm install 1.9.3-p374"
    su - vagrant -c "rvm use 1.9.3-p374 --default"
    
    echo "gem: --no-rdoc --no-ri" >> /etc/gemrc
    su - vagrant -c "echo 'gem: --no-rdoc --no-ri' >> ~/.gemrc"

## Postgres 9.1

Configure so that the vagrant user doesn't need to provide username and password.

    apt-get -yqq install postgresql postgresql-contrib-9.1 libpq-dev postgresql-server-dev-9.1
    su - postgres
    psql -c "CREATE USER vagrant WITH PASSWORD 'password';"
    psql -c "ALTER USER vagrant WITH PASSWORD 'password';"
    createdb vagrant
    psql -c "CREATE EXTENSION hstore;"
    psql -c "ALTER USER vagrant CREATEDB"
    psql -c "create database discourse_development owner vagrant encoding 'UTF8' TEMPLATE template0;"
    psql -c "create database discourse_test        owner vagrant encoding 'UTF8' TEMPLATE template0;"

Also, a user "discourse" is needed when importing a database image.

    createuser --createdb --superuser discourse
    psql -c "ALTER USER discourse WITH PASSWORD 'password';"

Edit /etc/postgresql/9.1/main/pg_hba.conf to have this:

    local all all trust 
    host all all 127.0.0.1/32 trust
    host all all ::1/128 trust
    host all all 0.0.0.0/0 trust # wide-open

Download a database image from [http://discourse.org/vms/dev-discourse-seed.sql][1]

Load it (as vagrant user):

    psql -d discourse_development < dev-discourse-seed.sql

## Redis

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