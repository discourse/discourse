# This is a set of sample deployment recipes for deploying via Capistrano.
# One of the recipes (deploy:symlink_nginx) assumes you have an nginx configuration
# file at config/nginx.conf. You can make this easily from the provided sample
# nginx configuration file.
#
# For help deploying via Capistrano, see this thread:
# http://meta.discourse.org/t/deploy-discourse-to-an-ubuntu-vps-using-capistrano/6353

require 'bundler/capistrano'
require 'sidekiq/capistrano'

# Repo Settings
# You should change this to your fork of discourse
set :repository, 'git@github.com:discourse/discourse.git'
set :deploy_via, :remote_cache
set :branch, fetch(:branch, 'master')
set :scm, :git
ssh_options[:forward_agent] = true

# General Settings
set :deploy_type, :deploy
default_run_options[:pty] = true

# Server Settings
set :user, 'admin'
set :use_sudo, false
set :rails_env, :production

role :app, 'SERVER_ADDRESS_HERE', primary: true
role :db,  'SERVER_ADDRESS_HERE', primary: true
role :web, 'SERVER_ADDRESS_HERE', primary: true

# Application Settings
set :application, 'discourse'
set :deploy_to, "/var/www/#{application}"

# Perform an initial bundle
after "deploy:setup" do
  run "cd #{current_path} && bundle install"
end

# Tasks to start/stop/restart thin
namespace :deploy do
  desc 'Start thin servers'
  task :start, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && bundle exec thin -C config/thin.yml start", :pty => false
  end

  desc 'Stop thin servers'
  task :stop, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && bundle exec thin -C config/thin.yml stop"
  end

  desc 'Restart thin servers'
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_path} && bundle exec thin -C config/thin.yml restart"
  end
end

# Symlink config/nginx.conf to /etc/nginx/sites-enabled. Make sure to restart
# nginx so that it picks up the configuration file.
namespace :config do
  task :nginx, roles: :app do
    puts "Symlinking your nginx configuration..."
    sudo "ln -nfs #{release_path}/config/nginx.conf /etc/nginx/sites-enabled/#{application}"
  end
end

after "deploy:setup", "config:nginx"

# Seed your database with the initial production image. Note that the production
# image assumes an empty, unmigrated database.
namespace :db do
  desc 'Seed your database for the first time'
  task :seed do
    run "cd #{current_path} && psql -d discourse_production < pg_dumps/production-image.sql"
  end
end

# Migrate the database with each deployment
after  'deploy:update_code', 'deploy:migrate'
