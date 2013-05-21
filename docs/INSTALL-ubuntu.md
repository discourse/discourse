# Discourse Install Guide on Ubuntu

## Install Ubuntu 12.04 with the package groups:

* Basic ubuntu server
* OpenSSH server
* Mail server
* PostgreSQL database (9.1+)

### Configure the mail server:

In our example setup, we're going to configure as a 'Satellite system', forwarding all mail to our egress servers for delivery. You'll probably want to do that unless you're handling mail on the same machine as the Discourse software.

Install necessary packages:

    # Run these commands as your normal login (e.g. "michael")
    sudo apt-get -y install build-essential libssl-dev libyaml-dev git libtool libxslt-dev libxml2-dev redis-server libpq-dev gawk curl pngcrush

## Install nginx

At Discourse, we recommend the latest version of nginx. To install on Ubuntu:

    # Run these commands as your normal login (e.g. "michael")
    # Remove any existing versions of nginx
    sudo apt-get remove '^nginx.*$'

    # Add nginx repo to sources.list
    cat <<'EOF' | sudo tee -a /etc/apt/sources.list

    deb http://nginx.org/packages/ubuntu/ precise nginx
    deb-src http://nginx.org/packages/ubuntu/ precise nginx
    EOF

    # Add nginx key
    curl http://nginx.org/keys/nginx_signing.key | sudo apt-key add -

    # install nginx
    sudo apt-get update && sudo apt-get -y install nginx

## Install rvm and ruby environment

### Systemwide installation

Taken from http://rvm.io/, the commands below installs RVM and users in the 'rvm' group have access to modify state:

    # Run these commands as your normal login (e.g. "michael")
    \curl -s -S -L https://get.rvm.io | sudo bash -s stable
    sudo adduser $USER rvm
    newgrp rvm
    . /etc/profile.d/rvm.sh
    rvm requirements

    # Build and install ruby
    rvm install 2.0.0
    gem install bundler


## Discourse setup

Create discourse user:

    # Run these commands as your normal login (e.g. "michael")
    sudo adduser --shell /bin/bash discourse
    sudo adduser discourse rvm

Give postgres DB rights to the `discourse` user:

    # Run these commands as your normal login (e.g. "michael")
    sudo -u postgres createuser -s discourse
    sudo -u postgres psql -c "alter user discourse password 'todayisagooddaytovi';"

Change to the 'discourse' user:

    # Run this command as your normal login (e.g. "michael"), further commands should be run as 'discourse'
    sudo su - discourse

    # Pull down the latest code
    git clone git://github.com/discourse/discourse.git

    # Install necessary gems
    cd discourse
    bundle install --deployment

_If you have errors building the native extensions, ensure you have sufficient free system memory. 1GB with no swap won't cut it._

Configure discourse:

    # Run these commands as the discourse user
    cd ~/discourse/config
    for i in {database,redis}.yml discourse.pill; do cp $i.sample $i; done
    cp environments/production.sample.rb environments/production.rb

Edit discourse/config/database.yml

- remove profile and development
- leave in production and perhaps test
- change production db name to: `discourse_prod`
- Change `host_names` to the name you'll use to access the discourse site

Edit discourse/config/redis.yml

- no changes if this is the only application using redis, but have a look

Edit discourse/config/discourse.pill

- change application name from 'your_app' to however you want to distinguish this ('discourse')
- Add option to Bluepill.application: `":base_dir => ENV["HOME"] + '/.bluepill'"`
- comment out debug instance
- search for "host to run on" and change to current hostname
- note: clockwork should run on only one host

Edit discourse/config/initializers/secret_token.rb
- uncomment secret_token line
- replace SET_SECRET_HERE with secret output from 'rake secret' command in discourse directory

Edit discourse/config/environments/production.rb
- check settings, modify smtp settings if necessary
- See http://meta.discourse.org/t/all-of-my-internal-users-show-as-coming-from-127-0-0-1/6607 if this will serve "internal" users

Initialize the database:

    # Run these commands as the discourse user
    # The database name here should match the production one in database.yml
    createdb discourse_prod
    RUBY_GC_MALLOC_LIMIT=900000000 RAILS_ENV=production bundle exec rake db:migrate
    RUBY_GC_MALLOC_LIMIT=900000000 RAILS_ENV=production bundle exec rake assets:precompile

## nginx setup

    # Run these commands as your normal login (e.g. "michael")
    sudo cp ~discourse/discourse/config/nginx.sample.conf /etc/nginx/conf.d/discourse.conf

Edit /etc/nginx/conf.d/discourse.conf

- change socket paths to: "unix:/home/discourse/discourse/tmp/sockets/thin.0.sock;"
- edit `server_name`. Example: "server_name cain.discourse.org test.cain.discourse.org;"
- modify root location to match installed location: "root /home/discourse/discourse/public;"

## Bluepill setup

Configure bluepill:

    # Run these commands as the discourse user
    gem install bluepill
    echo 'alias bluepill="bluepill --no-privileged -c ~/.bluepill"' >> ~/.bash_aliases
    rvm wrapper $(rvm current) bootup bluepill
    rvm wrapper $(rvm current) bootup bundle

Start Discourse:

    # Run these commands as the discourse user
    RUBY_GC_MALLOC_LIMIT=900000000 RAILS_ROOT=~/discourse RAILS_ENV=production NUM_WEBS=4 bluepill --no-privileged -c ~/.bluepill load ~/discourse/config/discourse.pill

Add the bluepill startup to crontab.

    # Run these commands as the discourse user
    crontab -e

Add the following line:

    @reboot RUBY_GC_MALLOC_LIMIT=900000000 RAILS_ROOT=~/discourse RAILS_ENV=production NUM_WEBS=4 bluepill --no-privileged -c ~/.bluepill load ~/discourse/config/discourse.pill

Congratulations! You've got Discourse installed and running!

<!--
Now you have to deliver the service to your users.

<strong>CDN</strong>

<h3>haproxy</h3>
<pre>listen http-in
        bind 64.71.148.2:80
        acl is_bare hdr(host) -i discourse.org
        acl is_home hdr(host) -i www.discourse.org
        acl is_blog hdr(host) -i blog.discourse.org
        # Discourse
        acl is_app hdr(host) -i meta.discourse.org
        acl is_app hdr(host) -i try.discourse.org
        # How-To-Geek
        acl is_app hdr(host) -i discuss.howtogeek.com

        # Redirect to www
        redirect prefix http://www.discourse.org if is_bare
        use_backend home if is_home
        use_backend blog if is_blog
        use_backend app if is_app
        default_backend app

backend app
        mode http
        balance roundrobin
        option http-server-close
        option forwardfor # This sets X-Forwarded-For
        option httpchk GET /srv/status HTTP/1.1\r\nHost:\ meta.discourse.org
        server  app2_00 10.0.0.2:9100 check
        server  app2_01 10.0.0.2:9101 check
        server  app3_00 10.0.0.3:9100 check
        server  app3_01 10.0.0.3:9101 check
        server  app4_00 10.0.0.4:9100 check
        server  app4_01 10.0.0.4:9101 check
        server  app5_00 10.0.0.5:9100 check
        server  app5_01 10.0.0.5:9101 check

backend home
        mode http
        balance roundrobin
        option http-server-close
        option forwardfor # This sets X-Forwarded-For
        server  home_app1_1 10.0.0.2:80

backend blog
        mode http
        balance roundrobin
        server  app1_1 10.0.0.40:80
</pre>
-->
