# Developing under OS X Without Vagrant

These instructions assume you have read and understood the **[Discourse Advanced Developer Install Guide](https://github.com/discourse/discourse/blob/master/docs/DEVELOPER-ADVANCED.md)**. 

While you can, of course, build or use a vagrant environment on OS X, if you already develop Rails apps on OS X, you might prefer to just work in your native environment. These instructions assume you're already developing with Ruby, at least, if not with Rails, natively on OS X.

As the OS X page at rvm.io suggests, setting up the environment to be "safe" for building one's own ruby environment is slightly fraught with peril because of Apple's switch to CLANG based compilers. If you're **not** already working successfully with RVM-based Ruby in OS X, it might be easier to stick with vagrant/Linux for now!

## Unicode

OS X 10.8 uses Unicode by default. You can, of course, double-check this by examining LANG, which appears to be the only relevant environment variable.

## RVM and Ruby

RVM supports OS X. For other 'packages', **[Homebrew](http://mxcl.github.com/homebrew)** is recommended as the package manager. Brew is very different from Apt, in that it often installs from source, and almost always installs development files as well as binaries, especially for libraries, so there are no special '-dev' packages.

While some people dislike magic, I recommend letting RVM do the dirty work for you. The following invocations will cover all of the ground that the Ubuntu instructions cover with apt-get.

If you don't have RVM installed, the "official" install command line on rvm.io will take care of just about everything you need:

    curl -L https://get.rvm.io | bash -s stable --rails --autolibs=enabled # Or, --ruby=1.9.3

If you do already have RVM installed, this should make sure everything is up to date for what you'll need.

    rvm get stable

    # Tell RVM to install anything its missing. Use '4' if homebrew isn't installed either.
    rvm autolibs 3

    # This will install baseline requirements that might be missing, including homebrew.
    # If autolibs is set to 0-2, it will give an error for things that are missing, instead.
    rvm requirements

    # Now, install Ruby
    rvm install 2.0.0-turbo
    rvm use 2.0.0-turbo --default # Careful with this if you're already developing Ruby

## Postgres 9.2

**NOTA BENE** As I'm writing this, Postgres is known to have some sort of hideous security problem that is supposed to be patched Real Soon Now. Be careful!

OS X ships with postgres, but you're better off going with the latest from Homebrew.

Whereas Ubuntu installs postgres with 'postgres' as the default superuser, Homebrew installs it with the user who installed it as such...and yet with 'postgres' as the default database. Go figure. However, the seed data currently has some dependencies on their being a 'postgres' user, so we create one below.

In theory, you're not setting up with vagrant, either, and shouldn't need a vagrant user; however, again, all the seed data assumes 'vagrant'. To avoid headaches, it's probably best to go with this flow, so again, we create a 'vagrant' user.

Using Homebrew:

    brew install postgresql # Installs 9.2
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

You should not need to alter /usr/local/var/postgres/pg_hba.conf

## Redis

    brew install redis

That's about it.

## PhantomJS

Homebrew loves you.

    brew install phantomjs




