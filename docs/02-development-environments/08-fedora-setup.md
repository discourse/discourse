---
title: Set up Discourse for development on Fedora Linux
short_title: Fedora setup
id: fedora-setup

---
This guide has been tested against a fresh install of Fedora 31 and 33, but may work on older versions that also use dnf as the package management tool. This is not an official guide but may be useful for other developers using Fedora. This is largely based on the [Ubuntu development guide](https://meta.discourse.org/t/beginners-guide-to-install-discourse-on-ubuntu-for-development/14727), with changes for the different packages for dnf. The assumption is that you do not have any of the packages installed already, although most will be skipped by the tooling if it is already installed.

If you're looking to install Discourse for a **production environment**, prefer the [docker install instructions on github](https://github.com/discourse/discourse/blob/master/docs/INSTALL.md). 

**Install required system and development packages**
```
sudo dnf update
sudo dnf install -y "@development-tools" git rpm-build zlib-devel ruby-devel readline-devel libpq-devel ImageMagick sqlite sqlite-devel nodejs npm curl gcc g++ bzip2 openssl-devel libyaml-devel libffi-devel zlib-devel gdbm-devel ncurses-devel optipng pngquant jhead jpegoptim gifsicle oxipng
```
**Install required npm packages**
```
sudo npm install -g svgo pnpm
```
**Install and setup postgres**
```
sudo dnf install postgresql-server postgresql-contrib
sudo postgresql-setup --initdb --unit postgresql
sudo systemctl enable postgresql
sudo systemctl start postgresql
sudo -u postgres -i createuser -s $USER
```
**Install and setup redis**
```
sudo dnf install redis
sudo systemctl enable redis
sudo systemctl start redis
```
**Installing rbenv, ruby-build, and ruby**
```
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
cd ~/.rbenv && src/configure && make -C src
~/.rbenv/bin/rbenv init
printf 'export PATH="$HOME/.rbenv/bin:$PATH"\n' >> ~/.bashrc
printf 'eval "$(rbenv init - --no-rehash)"\n' >> ~/.bashrc
source ~/.bashrc
git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
# confirm the install is correct
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/main/bin/rbenv-doctor | bash
rbenv install 2.7.1
rbenv global 2.7.1
rbenv rehash
```
**Install Ruby dependencies**
```
gem update --system
gem install bundler mailcatcher rails
```
**Clone Discourse code**
```
git clone https://github.com/discourse/discourse.git ~/discourse
cd ~/discourse
```
**Install Discourse dependencies**
```
bundle install
pnpm install
```
**Create the required databases and load the schema**
```
bundle exec rake db:create db:migrate
RAILS_ENV=test bundle exec rake db:create db:migrate
```

**Test installation by running the tests**
```
bundle exec rake autospec
```

**Run the application**
```
bundle exec rails server
```
You should now be able to see the Discourse setup page at http://localhost:3000.


For further setup, see the [existing official install guides.](https://meta.discourse.org/tag/dev-install)
