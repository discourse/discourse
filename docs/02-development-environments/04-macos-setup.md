---
title: Install Discourse on macOS for development
short_title: macOS setup
id: macos-setup
---

> :warning: This guide covers installation instructions for a macOS development environment, for production guides see: https://meta.discourse.org/t/how-to-install-discourse-in-production/142537

So you want to set up Discourse on macOS to hack on and develop with?

We'll assume that you don't have Ruby/Rails/Postgres/Redis installed on your Mac. Let's begin :rocket: !

## Install Discourse Dependencies

You will need the following packages on your system:

- [Git][git_link]
- [rbenv][rbenv_link] or [asdf][asdf_link]
- [ruby-build][ruby_build_link]
- [Ruby][ruby_link] (latest stable)
- [Rails][rails_link]
- [PostgreSQL][pg_link]
- [SQLite][sqlite_link]
- [Redis][redis_link]
- [Node.js][node_link]
- [pnpm][pnpm_link]
- [MailHog][mh_link]\*\*
- [ImageMagick][imagemagick_link]\*\*

_\*\* optional_

> restart your terminal

Now that we have installed Discourse dependencies, let's move on to install Discourse itself.

## Restart your Terminal

Exit your shell and restarting it ensures that the paths to the installed packages are correctly picked up by the Terminal.

## Clone Discourse

Clone the Discourse repository in `~/discourse` folder:

```sh
git clone https://github.com/discourse/discourse.git ~/discourse
```

_`~` indicates home folder, so Discourse source code will be available in your home folder._

## Bootstrap Discourse

Switch to your Discourse folder:

```sh
cd ~/discourse
```

Install the needed gems

```sh
bundle install
```

Install the JS dependencies

```sh
pnpm install
```

Next, run these commands to set up your local Discourse instance:

```sh
bundle exec rake db:create
bundle exec rake db:migrate
RAILS_ENV=test bundle exec rake db:create db:migrate
```

Start rails + Ember servers, you have two options here.

**Option 1**: using two separate Terminal tabs/windows, run Rails and Ember CLI separately via

```sh
bundle exec rails server
```

and

```sh
bin/ember-cli
```

**Option 2**: using only one Terminal tab/window:

```sh
bin/ember-cli -u # will run the Unicorn server in the background
```

:tada: You should now be able to navigate to [http://localhost:4200](http://localhost:4200) to see your local Discourse installation. (Note that the first load can take up to a minute as the server is warmed up.)

You can also try running the specs:

```sh
bundle exec rake autospec
```

All (or almost all) the tests should pass.

## Create New Admin

To create a new admin, run the following command:

```sh
RAILS_ENV=development bundle exec rake admin:create
```

Follow the prompts to create an admin account.

## Configure Mail

Run MailHog:

```sh
mailhog
```

---

Congratulations! You are now the admin of your own Discourse installation!

Happy hacking! And to get started with that, see [Beginner’s Guide to Creating Discourse Plugins](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins/30515).

[git_link]: http://git-scm.com/
[rbenv_link]: https://github.com/sstephenson/rbenv
[asdf_link]: https://asdf-vm.com/guide/getting-started.html
[node_link]: https://nodejs.org/en
[ruby_build_link]: https://github.com/sstephenson/ruby-build
[ruby_link]: https://www.ruby-lang.org/
[rails_link]: http://rubyonrails.org/
[pg_link]: http://www.postgresql.org/
[sqlite_link]: https://sqlite.org/
[redis_link]: http://redis.io/
[imagemagick_link]: http://www.imagemagick.org/
[pnpm_link]: https://pnpm.io/
[mh_link]: https://github.com/mailhog/MailHog
