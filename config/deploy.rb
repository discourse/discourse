# https://github.com/mina-deploy/mina/tree/master/docs
require 'mina/bundler'
require 'mina_sidekiq/tasks'
require 'mina/puma'
require 'mina/rails'
require 'mina/git'
require 'mina/rbenv'

set :application_name, 'Discourse'
set :user, 'discourse' # Username in the server to SSH to.
set :repository, 'https://github.com/edgeryders/discourse.git'
# The 'production' environment is also used for the staging website. Database settings are defined in
# defined in '/home/discourse/staging/shared/config/discourse.conf'.
set :rails_env, 'production'

# shared dirs and files will be symlinked into the app-folder by the 'deploy:link_shared_paths' step.
set :shared_dirs, fetch(:shared_dirs, []).push('public/backups', 'public/uploads')
set :shared_files, fetch(:shared_files, []).push('config/discourse.conf', 'config/puma.rb')


task :staging do
  set :domain, 'staging.edgeryders.eu'
  set :deploy_to, '/home/discourse/staging'
  set :branch, 'master'
end

task :production do
  set :domain, 'discourse.edgeryders.eu'
  set :deploy_to, '/home/discourse/production'
  set :branch, 'master'
end

# This task is the environment that is loaded for all remote run commands, such as
# `mina deploy` or `mina rake`.
task :environment do
  # If you're using rbenv, use this to load the rbenv environment.
  # Be sure to commit your .ruby-version or .rbenv-version to your repository.
  invoke :'rbenv:load'
end

# mina staging deploy force_asset_precompile=true
desc "Deploys the current version to the server."
task deploy: :environment do
  # uncomment this line to make sure you pushed your local branch to the remote origin
  invoke :'git:ensure_pushed'

  deploy do
    # stop accepting new workers
    invoke :'sidekiq:quiet'

    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'
    invoke :'deploy:cleanup'

    on :launch do
      in_path(fetch(:current_path)) do
        command %{mkdir -p tmp/sockets/}
      end

      # invoke :'puma:phased_restart'
      invoke :'puma:hard_restart'
      # invoke :'sidekiq:restart'
    end
  end

  # you can use `run :local` to run tasks on local machine before of after the deploy scripts
  # run(:local){ say 'done' }
end


desc 'Starts an interactive console.'
task console: :environment do
  set :execution_mode, :exec
  in_path "#{fetch(:current_path)}" do
    command %{#{fetch(:rails)} console}
  end
end


# mina staging deploy discourse_setup
# mina staging discourse_setup
task discourse_setup: :environment do
  in_path(fetch(:current_path)) do
    command %{#{fetch(:rake)} db:drop}
    command %{#{fetch(:rake)} db:create}
    command %{#{fetch(:rake)} db:migrate}
    comment %{Import data:}
    command %{DRUPAL_DB=edgeryders_drupal DRUPAL_FILES_DIR=/home/discourse/staging/shared/import/web/sites/edgeryders.eu/files #{fetch(:bundle_prefix)} ruby script/import_scripts/drupal_er.rb}
  end
end
