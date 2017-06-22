set :chruby_ruby, 'ruby-2.3.1'


set :application,     'discourse'
set :repo_url,        'https://github.com/edgeryders/discourse.git'
set :user,            'discourse'
set :deploy_to,       "/home/discourse/#{fetch(:stage)}"
set :use_sudo,        false
set :deploy_via,      :remote_cache
set :ssh_options,     { forward_agent: true, user: fetch(:user), keys: %w(~/.ssh/id_rsa.pub) }
# There is a known bug that prevents sidekiq from starting when pty is true on Capistrano 3.
# See: https://github.com/seuros/capistrano-sidekiq
set :pty,             false
## Linked Files & Directories (Default None):
set :linked_files, fetch(:linked_files, []).push('config/discourse.conf', 'config/puma.rb')
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle',  'public/system', 'public/backups', 'public/uploads')
## Defaults:
# set :scm,           :git
# set :branch,        :master
# set :format,        :pretty
# set :log_level,     :debug
# set :keep_releases, 5


# https://github.com/capistrano/rbenv
# set :rbenv_ruby, '2.3.1'
# set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
# set :rbenv_custom_path, fetch(:shared_path).join('rbenv')

# set :rbenv_ruby, File.read('.ruby-version').strip
#set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
# set :rbenv_map_bins, %w{rake gem bundle ruby rails}
# set :rbenv_roles, :all # default value
# set :rbenv_type, :user # or :system, depends on your rbenv setup
# set :rbenv_ruby, '2.0.0-p247'
# in case you want to set ruby version from the file:


# https://github.com/capistrano/bundler
set :bundle_path, -> { fetch(:shared_path).join('vendor', 'bundle') }


# https://github.com/capistrano/rails
# Defaults to false
# Skip migration if files in db/migrate were not modified
set :conditionally_migrate, true


# https://github.com/seuros/capistrano-puma
set :puma_conf, "#{fetch(:shared_path)}/config/puma.rb"
set :puma_threads, [4, 16]
set :puma_workers, 4
set :puma_init_active_record, true
set :puma_preload_app, false
set :puma_daemonize, true
append :rbenv_map_bins, 'puma', 'pumactl'
# set :puma_user, fetch(:user)
# set :puma_rackup, -> { File.join(current_path, 'config.ru') }
# set :puma_state, "#{shared_path}/tmp/pids/puma.state"
# set :puma_pid, "#{shared_path}/tmp/pids/puma.pid"
# set :puma_control_app, false
# set :puma_default_control_app, "unix://#{shared_path}/tmp/sockets/pumactl.sock"
# set :puma_access_log, "#{shared_path}/log/puma_access.log"
# set :puma_error_log, "#{shared_path}/log/puma_error.log"
# set :puma_role, :app
# set :puma_env, fetch(:rack_env, fetch(:rails_env, 'production'))
# set :puma_worker_timeout, nil
# set :puma_plugins, []  #accept array of plugins
# set :puma_tag, fetch(:application)



# https://github.com/seuros/capistrano-sidekiq
# set :sidekiq_default_hooks, -> { true }
# set :sidekiq_pid, -> { File.join(shared_path, 'tmp', 'pids', 'sidekiq.pid') }
# set :sidekiq_env, -> { fetch(:rack_env, fetch(:rails_env, fetch(:stage))) }
# set :sidekiq_log, -> { File.join(shared_path, 'log', 'sidekiq.log') }
# set :sidekiq_timeout, -> { 10 }
# set :sidekiq_role, -> { :app }
# set :sidekiq_processes, -> { 1 }
# set :sidekiq_options_per_process, -> { nil }
# set :sidekiq_user, -> { nil }
# # Rbenv, Chruby, and RVM integration
# set :rbenv_map_bins, fetch(:rbenv_map_bins).to_a.concat(%w(sidekiq sidekiqctl))
# set :rvm_map_bins, fetch(:rvm_map_bins).to_a.concat(%w(sidekiq sidekiqctl))
# set :chruby_map_bins, fetch(:chruby_map_bins).to_a.concat(%w{ sidekiq sidekiqctl })
# # Bundler integration
# set :bundle_bins, fetch(:bundle_bins).to_a.concat(%w(sidekiq sidekiqctl))
