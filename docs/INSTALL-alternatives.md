# Alternative Install Options

Here lie some alternative installation options for Discourse. They're not the
recommended way of doing things, hence they're a bit out of the way.

Oh, and dragons. Lots of dragons.

## Web Server Alternative: apache2

If you instead want to use apache2 to serve the static pages:

    # Run these commands as your normal login (e.g. "michael")
    # If you don't have apache2 yet
    sudo apt-get install apache2

    # Edit your site details in a new apache2 config file
    sudo vim /etc/apache2/sites-available/your-domain.com

    # Put these info inside and change accordingly

    <VirtualHost *:80>
      ServerName your-domain.com
      ServerAlias www.your-domain.com

      DocumentRoot /srv/www/apps/discourse/public

      <Directory /srv/www/apps/discourse/public>
        AllowOverride all
        Options -MultiViews
      </Directory>

      # Custom log file locations
      ErrorLog  /srv/www/apps/discourse/log/error.log
      CustomLog /srv/www/apps/discourse/access.log combined
    </VirtualHost>

    # Install the Passenger Phusion gem and run the install
    gem install passenger
    passenger-install-apache2-module

    # Next, we "create" a new apache2 module, passenger
    sudo vim /etc/apache2/mods-available/passenger.load

    # Inside paste (change the user accodingly)
    LoadModule passenger_module /home/YOUR-USER/.rvm/gems/ruby-2.0.0-p0/gems/passenger-4.0.2/libout/apache2/mod_passenger.so

    # Now the passenger module configuration
    sudo vim /etc/apache2/mods-available/passenger.conf

    # Inside, paste (change the user accodingly)
    PassengerRoot /home/YOUR-USER/.rvm/gems/ruby-2.0.0-p0/gems/passenger-4.0.2
    PassengerDefaultRuby /home/YOUR-USER/.rvm/wrappers/ruby-2.0.0-p0/ruby

    # Now activate them all

    sudo a2ensite your-domain.com
    sudo a2enmod passenger
    sudo service apache2 reload
    sudo service apache2 restart

If you get any errors starting or reloading apache, please check the paths above - Ruby 2.0 should be there if you are using RVM, but it could get tricky.

## RVM Alternative: Systemwide installation

Taken from http://rvm.io/, the commands below installs RVM and users in the 'rvm' group have access to modify state:

    # Run these commands as your normal login (e.g. "michael") \curl -s -S -L https://get.rvm.io | sudo bash -s stable
    sudo adduser $USER rvm
    newgrp rvm
    . /etc/profile.d/rvm.sh
    rvm requirements

    # Build and install ruby
    rvm install 2.0.0
    gem install bundler

When creating the `discourse` user, add him/her/it to the RVM group:

    # Run these commands as your normal login (e.g. "michael")
    sudo adduser discourse rvm

RVM will be located in `/usr/local/rvm` directory instead of `/home/discourse/.rvm`, so update the crontab line respectively.
