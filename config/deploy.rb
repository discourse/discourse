set :application,     'discourse'
set :repo_url,        'https://github.com/edgeryders/discourse.git'
set :branch,          'stable'
set :user,            'discourse'
set :deploy_to,       "/home/discourse/#{fetch(:stage)}"
set :use_sudo,        false
set :deploy_via,      :remote_cache
# set :ssh_options,     { forward_agent: true, user: fetch(:user), keys: %w(~/.ssh/id_rsa.pub) }
# There is a known bug that prevents sidekiq from starting when pty is true on Capistrano 3.
# See: https://github.com/seuros/capistrano-sidekiq
set :pty,             false
## Linked Files & Directories (Default None):
set :linked_files, fetch(:linked_files, []).push('config/discourse.conf', 'config/puma.rb')
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system', 'public/backups', 'public/uploads')


# https://github.com/capistrano/chruby
set :chruby_ruby, 'ruby-2.5.3'
# Workaround for capistrano bug: https://github.com/capistrano/chruby/issues/7#issuecomment-214770540
set :default_env, { path: '/opt/rubies/ruby-2.5.3/lib/ruby/gems/2.5.0/bin:/opt/rubies/ruby-2.5.3/bin:$PATH' }


# https://github.com/capistrano/rails
# Defaults to false
# Skip migration if files in db/migrate were not modified
set :conditionally_migrate, true


# https://github.com/seuros/capistrano-puma
set :puma_conf, "#{shared_path}/config/puma.rb"
set :puma_threads, [4, 16]
set :puma_workers, 4
set :puma_init_active_record, true
set :puma_preload_app, false
set :puma_daemonize, true
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
set :sidekiq_queue, %w(critical default low)
# set :sidekiq_config,        "#{current_path}/config/sidekiq.yml"
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

# See: https://github.com/seuros/capistrano-puma/issues/188
append :chruby_map_bins, 'puma', 'pumactl'
