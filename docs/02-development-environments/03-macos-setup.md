---
title: Install Discourse on macOS for development
short_title: macOS setup
id: macos-setup

---
> :warning: This guide covers installation instructions for a macOS development environment, for production guides see: https://meta.discourse.org/t/how-to-install-discourse-in-production/142537

So you want to set up Discourse on macOS to hack on and develop with?

We'll assume that you don't have Ruby/Rails/Postgres/Redis installed on your Mac. Let's begin :rocket: !

## Install Discourse Dependencies

Run [this script][mac_script] in your Terminal (or equivalent), to setup your machine for Discourse development:

    bash <(curl -s https://raw.githubusercontent.com/discourse/install-rails/main/mac)

This script will install following new packages on your system:

* Homebrew
* [Git][git_link]
* [rbenv][rbenv_link]
* [ruby-build][ruby_build_link]
* [Ruby][ruby_link] (latest stable)
* [Rails][rails_link]
* [PostgreSQL][pg_link]
* [Redis][redis_link]
* [Bundler][bundler_link]
* Node
* [pnpm][pnpm_link]
* [MailHog][mh]

*In case you have any of this package pre-installed and don't want to run entire script, see the [script][mac_script] and pick the packages you don't have currently installed. The script is fine-tuned for Discourse, and includes all the packages required for Discourse installation.*

> restart your terminal 

Now that we have installed Discourse dependencies, let's move on to install Discourse itself.

## Restart your Terminal 

Exit your shell and restarting it ensures that the paths to the installed packages are correctly picked up by the Terminal.

## Clone Discourse

Clone the Discourse repository in `~/discourse` folder:

    git clone https://github.com/discourse/discourse.git ~/discourse

*`~` indicates home folder, so Discourse source code will be available in your home folder.*

## Bootstrap Discourse

Switch to your Discourse folder:

    cd ~/discourse

Install the needed gems

    bundle install

Install the JS dependencies

    pnpm install

Next, run these commands to set up your local Discourse instance:

    bundle exec rake db:create
    bundle exec rake db:migrate
    RAILS_ENV=test bundle exec rake db:create db:migrate

Start rails + Ember servers, you have two options here. 

**Option 1**: using two separate Terminal tabs/windows, run Rails and Ember CLI separately via 

    bundle exec rails server

and

    bin/ember-cli

**Option 2**: using only one Terminal tab/window: 

```bash
bin/ember-cli -u # will run the Unicorn server in the background
```

:tada: You should now be able to navigate to [http://localhost:4200](http://localhost:4200) to see your local Discourse installation. (Note that the first load can take up to a minute as the server is warmed up.) 

You can also try running the specs: 

    bundle exec rake autospec

All (or almost all) the tests should pass.

## Create New Admin

To create a new admin, run the following command:

    RAILS_ENV=development bundle exec rake admin:create

Follow the prompts to create an admin account. 

## Configure Mail

Run MailHog:

    mailhog

----

Congratulations! You are now the admin of your own Discourse installation!

Happy hacking! And to get started with that, see [Beginner’s Guide to Creating Discourse Plugins](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins/30515).


  [mac_script]: https://github.com/discourse/install-rails/blob/main/mac
  [git_link]: http://git-scm.com/
  [rbenv_link]: https://github.com/sstephenson/rbenv
  [ruby_build_link]: https://github.com/sstephenson/ruby-build
  [ruby_link]: https://www.ruby-lang.org/
  [rails_link]: http://rubyonrails.org/
  [pg_link]: http://www.postgresql.org/
  [phantom_link]: http://phantomjs.org/
  [redis_link]: http://redis.io/
  [bundler_link]: http://bundler.io/
  [pnpm_link]: https://pnpm.io/
  [docker_guide]: https://meta.discourse.org/t/beginners-guide-to-deploy-discourse-on-digital-ocean-using-docker/12156
  [short_name]: http://forums.macrumors.com/showthread.php?t=898855
  [mh]: https://github.com/mailhog/MailHog
