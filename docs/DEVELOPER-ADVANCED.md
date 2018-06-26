# Discourse Advanced Developer Install Guide

This guide is aimed at advanced Rails developers who have installed their own Rails apps before.

Note: If you are developing on a Mac, you will probably want to look at [these instructions](DEVELOPMENT-OSX-NATIVE.md) as well.

# Preparing a fresh Ubuntu install

To get your Ubuntu 16.04 LTS install up and running to develop Discourse and Discourse plugins follow the commands below. We assume an English install of Ubuntu.

    # Basics
    whoami > /tmp/username
    sudo add-apt-repository ppa:chris-lea/redis-server
    sudo apt-get -yqq update
    sudo apt-get -yqq install python-software-properties vim curl expect debconf-utils git-core build-essential zlib1g-dev libssl-dev openssl libcurl4-openssl-dev libreadline6-dev libpcre3 libpcre3-dev imagemagick postgresql postgresql-contrib-9.5 libpq-dev postgresql-server-dev-9.5 redis-server advancecomp gifsicle jhead jpegoptim libjpeg-turbo-progs optipng pngcrush pngquant gnupg2

    # Ruby
    curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
    curl -sSL https://get.rvm.io | bash -s stable
    echo 'gem: --no-document' >> ~/.gemrc

    # exit the terminal and open it again to activate RVM

    rvm install 2.5.1
    rvm --default use 2.5.1 # If this error out check https://rvm.io/integration/gnome-terminal
    gem install bundler mailcatcher

    # Postgresql
    sudo -u postgres -i
    createuser --superuser -Upostgres $(cat /tmp/username)
    psql -c "ALTER USER $(cat /tmp/username) WITH PASSWORD 'password';"
    exit

    # Node
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.2/install.sh | bash

    # exit the terminal and open it again to activate NVM

    nvm install node
    nvm alias default node
    npm install -g svgo


If everything goes alright, let's clone Discourse and start hacking:

    git clone https://github.com/discourse/discourse.git ~/discourse
    cd ~/discourse
    bundle install

    # run this if there was a pre-existing database
    bundle exec rake db:drop
    RAILS_ENV=test bundle exec rake db:drop

    # time to create the database and run migrations
    bundle exec rake db:create db:migrate
    RAILS_ENV=test bundle exec rake db:create db:migrate

    # run the specs (optional)
    bundle exec rake autospec # CTRL + C to stop

    # launch discourse
    bundle exec rails s -b 0.0.0.0 # open browser on http://localhost:3000 and you should see Discourse

Create an admin account with:

    bundle exec rake admin:create

If you ever need to recreate your database:

    bundle exec rake db:drop db:create db:migrate
    bundle exec rake admin:create
    RAILS_ENV=test bundle exec rake db:drop db:create db:migrate

Discourse does a lot of stuff async, so it's better to run sidekiq even on development mode:

    mailcatcher # open http://localhost:1080 to see the emails, stop with pkill -f mailcatcher
    bundle exec sidekiq # open http://localhost:3000/sidekiq to see queues
    bundle exec rails server

And happy hacking!
