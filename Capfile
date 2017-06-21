# Load DSL and set up stages
require "capistrano/setup"

# Include default deployment tasks
require "capistrano/deploy"

# Load the SCM plugin appropriate to your project:
#
# require "capistrano/scm/hg"
# install_plugin Capistrano::SCM::Hg
# or
# require "capistrano/scm/svn"
# install_plugin Capistrano::SCM::Svn
# or
require "capistrano/scm/git"
install_plugin Capistrano::SCM::Git


# https://github.com/seuros/capistrano-puma
require 'capistrano/puma'
install_plugin Capistrano::Puma  # Default puma tasks
install_plugin Capistrano::Puma::Workers  # if you want to control the workers (in cluster mode)
install_plugin Capistrano::Puma::Monit  # if you need the monit tasks
# install_plugin Capistrano::Puma, load_hooks: false  # Default puma tasks without hooks
# install_plugin Capistrano::Puma::Monit, load_hooks: false  # Monit tasks without hooks
# install_plugin Capistrano::Puma::Jungle # if you need the jungle tasks
# install_plugin Capistrano::Puma::Nginx  # if you want to upload a nginx site template


# Include tasks from other gems included in your Gemfile
#
# For documentation on these, see for example:
#
#   https://github.com/capistrano/rvm
#   https://github.com/capistrano/rbenv
#   https://github.com/capistrano/chruby
#   https://github.com/capistrano/bundler
#   https://github.com/capistrano/rails
#   https://github.com/capistrano/passenger
#
require "capistrano/rails"
require "capistrano/rbenv"
require "capistrano/bundler"
require 'capistrano/rails/migrations'
require 'capistrano/rails/assets'
require 'capistrano/puma'
require 'capistrano/sidekiq'
require 'capistrano/sidekiq/monit' #to require monit tasks # Only for capistrano3


# Load custom tasks from `lib/capistrano/tasks` if you have any defined
Dir.glob("lib/capistrano/tasks/*.rake").each { |r| import r }
