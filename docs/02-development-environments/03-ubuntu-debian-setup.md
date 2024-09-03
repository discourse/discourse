---
title: Install Discourse on Ubuntu or Debian for Development
short_title: Ubuntu/Debian setup
id: ubuntu-debian-setup

---
<div data-theme-toc="true"> </div>

> :warning: This guide covers installation instructions in a development environment. For a production guide see: https://meta.discourse.org/t/how-to-install-discourse-in-production/142537

------

So you want to set up Discourse on Ubuntu or Debian to hack on and develop with?

We'll assume that you work locally and don't have Ruby/Rails/Postgres/Redis installed on your Ubuntu or Debian system. Let's begin!

## Requirements
We suggest having at least 4 GB RAM and 2 CPU cores.

### Current compatibility:

|OS | Compatibility|
|--- | ---|
|Debian 11 | ✅|
|Crostini (Linux on ChromeOS)|✅|
|Ubuntu 22.04 or later | ✅|

## Install Discourse Dependencies

As regular user run [this script][linux_script] in terminal, to setup Rails development environment:-

```
bash <(wget -qO- https://raw.githubusercontent.com/discourse/install-rails/main/linux)
```

This will install the following new packages on your system:

* [Git][git_link]
* [rbenv][rbenv_link]
* [ruby-build][ruby_build_link]
* [Ruby][ruby_link] (stable)
* [Rails][rails_link]
* [PostgreSQL][pg_link]
* [SQLite][sqlite_link]
* [Redis][redis_link]
* [Bundler][bundler_link]
* [MailHog][mg]
* [ImageMagick][imagemagick_link]

*In case you have any of this package pre-installed and don't want to run the entire script, see the [script][linux_script] and pick the packages you don't have currently installed. The script is fine-tuned for Discourse, and includes all the packages required for Discourse installation.*

Now that we have installed Discourse dependencies, let's move on to install Discourse itself.

## Clone Discourse

Clone the Discourse repository in `~/discourse` folder:

```
git clone https://github.com/discourse/discourse.git ~/discourse
```

*`~` indicates home folder, so Discourse source code will be available in your home folder.*

## Setup Database

[details="Already completed by the install script"]
Create role **with the same name as your Linux system username**:

```
cd /tmp && sudo -u postgres createuser -s "$USER"
```
[/details]

## Bootstrap Discourse

Switch to your Discourse folder:

```
 cd ~/discourse
```
Install the needed gems

```
source ~/.bashrc
bundle install
```

Install the JS dependencies

```
pnpm install
```

Now that you have successfully installed gems, run these commands:

```
bin/rails db:create 
bin/rails db:migrate
RAILS_ENV=test bin/rails db:create db:migrate
```

Start rails and ember server:

```
bin/ember-cli -u
```
If the images are not appearing, use this command instead:
(*you can also specify an IP if you are working on a remote server*)
```
DISCOURSE_HOSTNAME=localhost UNICORN_LISTENER=localhost:3000 bin/ember-cli -u
```

You should now be able to navigate to [http://localhost:4200](http://localhost:4200) to see your local Discourse installation.

## Create New Admin

To create a new admin, run the following command:

```
bin/rails admin:create
```

Follow the prompts, and a new admin account will be created. 

## Configure Mail

Run MailHog:

```
mailhog
```

----

Congratulations! You are now the admin of your own Discourse installation!

Happy hacking! And to get started with that, see [Beginner’s Guide to Creating Discourse Plugins](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins/30515).


  [linux_script]: https://github.com/discourse/install-rails/blob/main/linux
  [git_link]: http://git-scm.com/
  [rbenv_link]: https://github.com/sstephenson/rbenv
  [ruby_build_link]: https://github.com/sstephenson/ruby-build
  [ruby_link]: https://www.ruby-lang.org/
  [rails_link]: http://rubyonrails.org/
  [pg_link]: http://www.postgresql.org/
  [sqlite_link]: https://sqlite.org/
  [redis_link]: http://redis.io/
  [bundler_link]: http://bundler.io/
  [imagemagick_link]: http://www.imagemagick.org/
  [meta]: https://meta.discourse.org/t/developers-guide-to-install-discourse-on-ubuntu/14727
  [gh]: https://github.com/techAPJ/discourse-development-ubuntu
  [install_guide]: https://github.com/discourse/discourse/blob/master/docs/INSTALL.md
  [docker_guide]: https://meta.discourse.org/t/beginners-guide-to-deploy-discourse-on-digital-ocean-using-docker/12156
  [mg]: https://github.com/mailhog/MailHog

---

*Last Reviewed by @blake on [date=2023-04-03 timezone="America/Boise"]*
