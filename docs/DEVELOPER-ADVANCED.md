# Discourse Advanced Developer Install Guide

This guide is aimed at advanced Rails developers who have installed their own Rails apps before. If you are new to Rails, you are likely much better off with our **[Discourse Vagrant Developer Guide](VAGRANT.md)**.

Note: If you are developing on a Mac, you will probably want to look at [these instructions](DEVELOPMENT-OSX-NATIVE.md) as well.

# Preparing a fresh Ubuntu install

To get your Ubuntu 16.04 LTS install up and running to develop Discourse and Discourse plugins follow the commands below. We assume and English install of Ubuntu.

    # Basics
    whoami > /tmp/username
    sudo add-apt-repository ppa:chris-lea/redis-server
    sudo apt-get -yqq update
    sudo apt-get -yqq install python-software-properties vim curl expect debconf-utils git-core build-essential zlib1g-dev libssl-dev openssl libcurl4-openssl-dev libreadline6-dev libpcre3 libpcre3-dev imagemagick postgresql postgresql-contrib-9.5 libpq-dev postgresql-server-dev-9.5 redis-server advancecomp gifsicle jhead jpegoptim libjpeg-progs optipng pngcrush pngquant

    # Ruby
    curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
    \curl -sSL https://get.rvm.io | bash -s stable
    echo 'gem: --no-document' >> ~/.gemrc
    rvm install 2.3.1
    rvm --default use 2.3.1 # If this error out check https://rvm.io/integration/gnome-terminal
    gem install bundler mailcatcher


    # Postgresql
    sudo su postgres
    createuser --createdb --superuser -Upostgres $(cat /tmp/username)
    psql -c "ALTER USER $(cat /tmp/username) WITH PASSWORD 'password';"
    psql -c "create database discourse_development owner $(cat /tmp/username) encoding 'UTF8' TEMPLATE template0;"
    psql -c "create database discourse_test        owner $(cat /tmp/username) encoding 'UTF8' TEMPLATE template0;"
    psql -d discourse_development -c "CREATE EXTENSION hstore;"
    psql -d discourse_development -c "CREATE EXTENSION pg_trgm;"

    # Node
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.1/install.sh | bash
    # exit the terminal and open it again
    nvm install 6.2.0
    nvm alias default 6.2.0
    npm install -g svgo phantomjs-prebuilt


If everything goes alright, let's clone Discourse and start hacking:

    git clone https://github.com/discourse/discourse.git ~/discourse
    cd ~/discourse
    bundle install
    bundle exec rake db:create db:migrate db:test:prepare
    bundle exec rake autospec # CTRL + C to stop
    bundle exec rails server # Open browser on http://localhost:3000 and you should see Discourse

Create a test account, and enable it with:

    bundle exec rails c
    u = User.find_by_id 1
    u.activate
    u.grant_admin!
    exit

Discourse does a lot of stuff async, so it's better to run sidekiq even on development mode:

    ruby $(mailcatcher) # open http://localhost:1080 to see the emails, stop with pkill -f mailcatcher
    bundle exec sidekiq -d -l log/sidekiq.log # open http://localhost:3000/sidekiq to see the queue, stop with pkill -f sidekiq
    bundle exec rails server

And happy hacking!
