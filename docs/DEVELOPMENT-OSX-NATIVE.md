# Developing under OS X Without Vagrant

These instructions assume you have read and understood the **[Discourse Advanced Developer Install Guide](DEVELOPER-ADVANCED.md)**.

OS X has become a popular platform for developing Ruby on Rails applications; as such, if you run OS X, you might find it more congenial to work on **[Discourse](http://discourse.org)** in your native environment. These instructions should get you there.

Obviously, if you **already** develop Ruby on OS X, a lot of this will be redundant, because you'll have already done it, or something like it. If that's the case, you may well be able to just install Ruby 2.0 using RVM and get started! Discourse has enough dependencies, however (note: not a criticism!) that there's a good chance you'll find **something** else in this document that's useful for getting your Discourse development started!

## UTF-8

OS X 10.8 uses UTF-8 by default. You can, of course, double-check this by examining LANG, which appears to be the only relevant environment variable.

You should see this:

```sh
$ echo $LANG
en_US.UTF
```

## OSX Development Tools

As the [RVM website](http://rvm.io) makes clear, there are some serious issues between MRI Ruby and the modern Xcode command line tools, which are based on CLANG and LLVM, rather than classic GCC.

This means that you need to do a little bit of groundwork if you do not already have an environment that you know for certain yields working rubies and gems.

You will want to install XCode Command Line Tools. If you already have XCode installed, you can do this from within XCode's preferences. You can also install just the command line tools, without the rest of XCode, at [Apple's developer site](https://developer.apple.com/downloads/index.action). You will need these more for some of the headers they include than the compilers themselves.

You will then need the old GCC-4.2 compilers, which leads us to...

## Homebrew

**[Homebrew](http://mxcl.github.com/homebrew)** is a package manager for ports of various Open Source packages that Apple doesn't already include (or newer versions of the ones they do), and competes in that space with MacPorts and a few others. Brew is very different from Apt, in that it often installs from source, and almost always installs development files as well as binaries, especially for libraries, so there are no special "-dev" packages.

RVM (below) can automatically install homebrew for you with the autolibs setting, but doesn't install the GCC-4.2 compiler package when it does so, possibly because that package is not part of the mainstream homebrew repository.

So, you will need to install Homebrew separately, based on the instructions at the website above, and then run the following from the command line:

    brew tap homebrew/dupes # roughly the same to adding a repo to apt/sources.list
    brew install apple-gcc42
    gcc-4.2 -v # Test that it's installed and available

(You may note the Homebrew installation script requires ruby. This is not a chicken-and-egg problem; OS X 10.8 comes with ruby 1.8.7)

## RVM and Ruby

While some people dislike magic, I recommend letting RVM do most of the dirty work for you.

### RVM from scratch

If you don't have RVM installed, the "official" install command line on rvm.io will take care of just about everything you need, including installing Homebrew if you don't already have it installed. If you do, it will bring things up to date and use it to install the packages it needs.

    curl -L https://get.rvm.io | bash -s stable --rails --autolibs=enabled

**IMPORTANT** As of this writing, there is a known bug in rubygems that will make it appear to not properly install. It's fibbing. It installs just fine.

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

    brew install git # 1.8.2 is current

You should now be able to check out a clone of Discourse.

### SourceTree

Atlassan has a free GIT client for OS X called [SourceTree](http://www.sourcetreeapp.com/download/) which can be extremely useful for keeping visual track of what's going on in Git-land. While it's arguably not a full substitute for command-line git (especially if you know the command line well), it's extremely powerful for a GUI version-control client.

## Postgres 9.2

**NOTA BENE** As I'm writing this, Postgres is known to have some sort of hideous security problem that is supposed to be patched Real Soon Now. Be careful!

OS X ships with Postgres 9.1.5, but you're better off going with the latest from Homebrew or [Postgres.App](http://postgresapp.com).

### Using Postgres.app

[Instructions pending]


### Using Homebrew:

Whereas Ubuntu installs postgres with 'postgres' as the default superuser, Homebrew installs it with the user who installed it as such...and yet with 'postgres' as the default database. Go figure. 

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

### Loading seed data

From the discource source tree:
    
    psql -d discourse_development < pg_dumps/development-image.sql

## Redis

    brew install redis
    ln -sfv /usr/local/opt/redis/*.plist ~/Library/LaunchAgents
    launchctl load ~/Library/LaunchAgents/homebrew.mxcl.redis.plist

That's about it.

## PhantomJS

Homebrew loves you.

    brew install phantomjs

## Now, test it out!

Copy `config/database.yml.development-sample` and `config/redis.yml.sample` to `config/database.yml` and `config/redis.yml` and input the correct values to point to your postgres and redis instances. If you stuck to all the defaults above, chances are the samples will work out of the box!

    bundle install # Yes, this DOES take a while. No, it's not really cloning all of rubygems :-)
    rake db:migrate
    rake db:test:prepare
    rake db:seed_fu
    bundle exec rspec # All specs should pass

