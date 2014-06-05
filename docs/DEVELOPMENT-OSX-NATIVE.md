# Developing under OS X Without Vagrant

These instructions assume you have read and understood the **[Discourse Advanced Developer Install Guide](DEVELOPER-ADVANCED.md)**.

OS X has become a popular platform for developing Ruby on Rails applications; as such, if you run OS X, you might find it more congenial to work on **[Discourse](http://discourse.org)** in your native environment. These instructions should get you there.

Obviously, if you **already** develop Ruby on OS X, a lot of this will be redundant, because you'll have already done it, or something like it. If that's the case, you may well be able to just install Ruby 2.0 using RVM and get started! Discourse has enough dependencies, however (note: not a criticism!) that there's a good chance you'll find **something** else in this document that's useful for getting your Discourse development started!

## Quick Setup

If you don't already have a Ruby environment that's tuned to your liking, you can do most of this set up in just a few steps:

1. Install XCode and/or the XCode Command Line Tools from [Apple's developer site](https://developer.apple.com/downloads/index.action). This should also install Git.
2. Clone the Discourse repo and cd into it.
3. Run `script/osx_dev`.
4. Review `log/osx_dev.log` to make sure everything finished successfully.

Of course, it is good to understand what the script is doing and why. The rest of this guide goes through what's happening.

## UTF-8

OS X 10.8 uses UTF-8 by default. You can, of course, double-check this by examining LANG, which appears to be the only relevant environment variable.

You should see this:

```sh
$ echo $LANG
en_US.UTF
```

## OS X Development Tools

As the [RVM website](http://rvm.io) makes clear, there are some serious issues between MRI Ruby and the modern Xcode command line tools, which are based on CLANG and LLVM, rather than classic GCC.

This means that you need to do a little bit of groundwork if you do not already have an environment that you know for certain yields working rubies and gems.

You will want to install XCode Command Line Tools. If you already have XCode installed, you can do this from within XCode's preferences. You can also install just the command line tools, without the rest of XCode, at [Apple's developer site](https://developer.apple.com/downloads/index.action). You will need these more for some of the headers they include than the compilers themselves.

You will then need the old GCC-4.2 compilers, which leads us to...

## Homebrew

**[Homebrew](http://mxcl.github.com/homebrew)** is a package manager for ports of various Open Source packages that Apple doesn't already include (or newer versions of the ones they do), and competes in that space with MacPorts and a few others. Brew is very different from Apt, in that it often installs from source, and almost always installs development files as well as binaries, especially for libraries, so there are no special "-dev" packages.

RVM (below) can automatically install homebrew for you with the autolibs setting, but doesn't install the GCC-4.2 compiler package when it does so, possibly because that package is not part of the mainstream homebrew repository.

So, you will need to install Homebrew separately, based on the instructions at the website above, and then run the following from the command line:

    brew tap homebrew/versions # roughly the same to adding a repo to apt/sources.list
    brew install apple-gcc42
    gcc-4.2 -v # Test that it's installed and available

(You may note the Homebrew installation script requires ruby. This is not a chicken-and-egg problem; OS X 10.8 comes with ruby 1.8.7)

## RVM and Ruby

While some people dislike magic, I recommend letting RVM do most of the dirty work for you.

### RVM from scratch

If you don't have RVM installed, the "official" install command line on rvm.io will take care of just about everything you need, including installing Homebrew if you don't already have it installed. If you do, it will bring things up to date and use it to install the packages it needs.

    curl -L https://get.rvm.io | bash -s stable --rails --autolibs=enabled

### Updating RVM

If you do already have RVM installed, this should make sure everything is up to date for what you'll need.

    rvm get stable

    # Tell RVM to install anything its missing. Use '4' if homebrew isn't installed either.
    rvm autolibs 3

    # This will install baseline requirements that might be missing, including homebrew.
    # If autolibs is set to 0-2, it will give an error for things that are missing, instead.
    rvm requirements

Either way, you'll now want to install the 'turbo' version of Ruby 2.0.

    # Now, install Ruby
    rvm install 2.0.0-turbo
    rvm use 2.0.0-turbo --default # Careful with this if you're already developing Ruby

## Git

### Command line

OS X comes with Git (which is why the LibXML2 dance above will work before this step!), but I recommend you update to Homebrew's version:

    brew install git # 1.8.5.3 is current

You should now be able to check out a clone of Discourse.

### SourceTree

Atlassan has a free Git client for OS X called [SourceTree](http://www.sourcetreeapp.com/download/) which can be extremely useful for keeping visual track of what's going on in Git-land. While it's arguably not a full substitute for command-line git (especially if you know the command line well), it's extremely powerful for a GUI version-control client.

## Postgres 9.2

OS X ships with Postgres 9.1.5, but you're better off going with the latest from Homebrew or [Postgres.App](http://postgresapp.com).

### Using Postgres.app

After installing the [Postgres93 App](http://postgresapp.com/), there is some additional setup that is necessary for discourse to create a database on your machine.

Open this file:
```
~/Library/Application Support/Postgres93/var/postgresql.conf
```
And change these two lines so that postgres will create a socket in the folder discourse expects it to:
```
unix_socket_directories = '/var/pgsql_socket'»# comma-separated list of directories
#and
unix_socket_permissions = 0777»·»·# begin with 0 to use octal notation
```
Then create the '/var/pgsql/' folder and set up the appropriate permission in your bash (this requires admin access)
```
sudo mkdir /var/pgsql_socket
sudo chmod 770 /var/pgsql_socket
sudo chown root:staff /var/pgsql_socket
```
Now you can restart Postgres.app and it will use this socket. Make sure you not only restart the app but kill any processes that may be left behind. You can view these processes with this bash command:
```
netstat -ln | grep PGSQL
```
And you should be good to go!

### Using Homebrew:

Whereas Ubuntu installs postgres with 'postgres' as the default superuser, Homebrew installs it with the user who installed it... but with 'postgres' as the default database. Go figure.

However, the seed data currently has some dependencies on their being a 'postgres' user, so we create one below.

In theory, you're not setting up with vagrant, either, and shouldn't need a vagrant user; however, again, all the seed data assumes 'vagrant'. To avoid headaches, it's probably best to go with this flow, so again, we create a 'vagrant' user.

    brew install postgresql # Installs 9.2
    ln -sfv /usr/local/opt/postgresql/*.plist ~/Library/LaunchAgents

    export PATH=/usr/local/opt/postgresql/bin:$PATH # You may want to put this in your default path!
    initdb /usr/local/var/postgres -E utf8
    launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist
    launchctl load ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist

    # Seed data relies on both 'postgres' and 'vagrant'
    createuser --createdb --superuser postgres
    createuser --createdb --superuser vagrant

    psql -d postgres -c "ALTER USER vagrant WITH PASSWORD 'password';"
    psql -d postgres -c "create database discourse_development owner vagrant encoding 'UTF8' TEMPLATE template0;"
    psql -d postgres -c "create database discourse_test        owner vagrant encoding 'UTF8' TEMPLATE template0;"
    psql -d discourse_development -c "CREATE EXTENSION hstore;"
    psql -d discourse_development -c "CREATE EXTENSION pg_trgm;"

You should not need to alter `/usr/local/var/postgres/pg_hba.conf`

## Redis

    brew install redis
    ln -sfv /usr/local/opt/redis/*.plist ~/Library/LaunchAgents
    launchctl load ~/Library/LaunchAgents/homebrew.mxcl.redis.plist

That's about it.

## PhantomJS

Homebrew loves you.

    brew install phantomjs

## ImageMagick

ImageMagick is used for generating avatars (including for test fixtures).

    brew install imagemagick

## Sending email (SMTP)

By default, development.rb will attempt to connect locally to send email.

```rb
config.action_mailer.smtp_settings = { address: "localhost", port: 1025 }
```

Set up [MailCatcher](https://github.com/sj26/mailcatcher) so the app can intercept
outbound email and you can verify what is being sent.

## Setting up your Discourse

###  Check out the repository

    git@github.com:discourse/discourse.git ~/discourse
    cd ~/discourse # Navigate into the repository, and stay there for the rest of this how-to

### What about the config files?

If you've stuck to all the defaults above, the default `discourse.conf` and `redis.conf` should work out of the box.

### Install the needed gems

    bundle install # Yes, this DOES take a while. No, it's not really cloning all of rubygems :-)

### Prepare your database

    rake db:migrate
    rake db:test:prepare
    rake db:seed_fu

## Now, test it out!

    bundle exec rspec

All specs should pass

### Deal with any problems which arise.

Reset the environment as a possible solution to failed rspec tests.
These commands assume an empty Discourse database, and an otherwise empty redis environment. CAREFUL HERE

    RAILS_ENV=test rake db:drop db:create db:migrate
    redis-cli flushall
    bundle exec rspec # re-running to see if tests pass

Search http://meta.discourse.org for solutions to other problems.
