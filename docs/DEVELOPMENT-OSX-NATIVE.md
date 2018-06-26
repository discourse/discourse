# Developing under OS X

These instructions assume you have read and understood the **[Discourse Advanced Developer Install Guide](DEVELOPER-ADVANCED.md)**.

OS X has become a popular platform for developing Ruby on Rails applications; as such, if you run OS X, you might find it more congenial to work on **[Discourse](http://discourse.org)** in your native environment. These instructions should get you there.

Obviously, if you **already** develop Ruby on OS X, a lot of this will be redundant, because you'll have already done it, or something like it. If that's the case, you may well be able to just install Ruby 2.3 using RVM and get started! Discourse has enough dependencies, however (note: not a criticism!) that there's a good chance you'll find **something** else in this document that's useful for getting your Discourse development started!

## Quick Setup

If you don't already have a Ruby environment that's tuned to your liking, you can do most of this set up in just a few steps:

1. Install XCode and/or the XCode Command Line Tools from [Apple's developer site](https://developer.apple.com/downloads/index.action). This should also install Git.
2. Clone the Discourse repo and cd into it.
3. Run `script/osx_dev`.
4. Review `log/osx_dev.log` to make sure everything finished successfully.
5. Jump To [Setting up your Discourse](#setting-up-your-discourse)

Of course, it is good to understand what the script is doing and why. The rest of this guide goes through what's happening.

## UTF-8

OS X 10.8 uses UTF-8 by default. You can, of course, double-check this by examining LANG, which appears to be the only relevant environment variable.

You should see this:

```sh
$ echo $LANG
en_US.UTF-8
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

    brew tap homebrew/dupes # roughly the same to adding a repo to apt/sources.list
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
    rvm install 2.3.4-turbo
    rvm use 2.3.4 --default # Careful with this if you're already developing Ruby

## Git

### Command line

OS X comes with Git (which is why the LibXML2 dance above will work before this step!), but I recommend you update to Homebrew's version:

    brew install git

You should now be able to check out a clone of Discourse.

### SourceTree

Atlassian has a free Git client for OS X called [SourceTree](http://www.sourcetreeapp.com/download/) which can be extremely useful for keeping visual track of what's going on in Git-land. While it's arguably not a full substitute for command-line git (especially if you know the command line well), it's extremely powerful for a GUI version-control client.

## Postgres 9.3

OS X ships with Postgres 9.1.5, but you're better off going with the latest from Homebrew or [Postgres.app](http://postgresapp.com).

### Using Postgres.app

After installing [Postgres.app](http://postgresapp.com/), there are some additional setup steps that are necessary for discourse to create a database on your machine.

Open this file:
```
~/Library/Application Support/Postgres/var-9.3/postgresql.conf
```
And change these two lines so that postgres will create a socket in the folder discourse expects it to:
```
unix_socket_directories = '/var/pgsql_socket'   # comma-separated list of directories
#and
unix_socket_permissions = 0777  # begin with 0 to use octal notation
```
Then create the '/var/pgsql_socket/' folder and set up the appropriate permission in your bash (this requires admin access)
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

#### Troubleshooting

If you get this error when starting `psql` from the command line:

    psql: could not connect to server: No such file or directory
    Is the server running locally and accepting
    connections on Unix domain socket "/tmp/.s.PGSQL.5432"?

it is because it is still looking in the `/tmp` directory and not in `/var/pgsql_socket`.

If running `psql -h /var/pgsql_socket` works then you need to configure the host in your `.bash_profile`:

```
export PGHOST="/var/pgsql_socket"
````

Then make sure to reload your config with: `source ~/.bash_profile`. Now `psql` should work.


### Using Homebrew:

Whereas Ubuntu installs postgres with 'postgres' as the default superuser, Homebrew installs it with the user who installed it... but with 'postgres' as the default database. Go figure.

However, the seed data currently has some dependencies on their being a 'postgres' user, so we create one below.

In theory, you're not setting up with vagrant, either, and shouldn't need a vagrant user; however, again, all the seed data assumes 'vagrant'. To avoid headaches, it's probably best to go with this flow, so again, we create a 'vagrant' user.

    brew install postgresql
    ln -sfv /usr/local/opt/postgresql/*.plist ~/Library/LaunchAgents

    export PATH=/usr/local/opt/postgresql/bin:$PATH # You may want to put this in your default path!
    initdb /usr/local/var/postgres -E utf8
    launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist
    launchctl load ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist

### Seed data relies on both 'postgres' and 'vagrant'

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

## Google Chrome 59+

Chrome is used for running QUnit tests in headless mode.

Download from https://www.google.com/chrome/index.html

## ImageMagick

ImageMagick is used for generating avatars (including for test fixtures). Brew installs ImageMagick 7 by default, and this version
doesn't work with Discourse.

    brew install imagemagick@6
    brew link --force imagemagick@6

ImageMagick is going to want to use the Helvetica font to generate the
letter-avatars:

```sh
brew install fondu
cd ~/Library/Fonts
fondu /System/Library/Fonts/Helvetica.dfont
mkdir ~/.magick
cd ~/.magick
curl http://www.imagemagick.org/Usage/scripts/imagick_type_gen > type_gen
find /System/Library/Fonts /Library/Fonts ~/Library/Fonts -name "*.[to]tf" | perl type_gen -f - > type.xml
cd /usr/local/Cellar/imagemagick/<version>/etc/ImageMagick-6
```

Edit system config file called "type.xml" and add line near end to tell IM to
look at local file we made in earlier step

```
<typemap>
<include file="type-ghostscript.xml" />
<include file="~/.magick/type.xml" />  ### THIS LINE ADDED
</typemap>
```

## Sending email (SMTP)

By default, development.rb will attempt to connect locally to send email.

```rb
config.action_mailer.smtp_settings = { address: "localhost", port: 1025 }
```

Set up [MailCatcher](https://github.com/sj26/mailcatcher) so the app can intercept
outbound email and you can verify what is being sent.

## Additional Image Tooling

In addition to ImageMagick we also need to install some other image related
software:

```sh
brew install gifsicle jpegoptim optipng jhead
npm install -g svgo
```

## Setting up your Discourse

###  Check out the repository
```sh
git clone git@github.com:discourse/discourse.git
cd discourse # Navigate into the repository, and stay there for the rest of this how-to
```
### What about the config files?

If you've stuck to all the defaults above, the default `discourse.conf` and `redis.conf` should work out of the box.

### Install the needed gems
```sh
bundle install
```

### Prepare your database
```sh
# run this if there was a pre-existing database
bundle exec rake db:drop
RAILS_ENV=test bundle exec rake db:drop

# time to create the database and run migrations
bundle exec rake db:create db:migrate
RAILS_ENV=test bundle exec rake db:create db:migrate
```

## Now, test it out!
```sh
bundle exec rspec
```
All specs should pass

### Deal with any problems which arise.

Reset the environment as a possible solution to failed rspec tests.
These commands assume an empty Discourse database, and an otherwise empty redis environment. CAREFUL HERE

    RAILS_ENV=test rake db:drop db:create db:migrate
    redis-cli flushall
    bundle exec rspec # re-running to see if tests pass

Search http://meta.discourse.org for solutions to other problems.
