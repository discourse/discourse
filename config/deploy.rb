

set :rbenv_type, :user # or :system, depends on your rbenv setup
# set :rbenv_ruby, '2.0.0-p247'
# in case you want to set ruby version from the file:
set :rbenv_ruby, File.read('.ruby-version').strip
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w{rake gem bundle ruby rails}
set :rbenv_roles, :all # default value

set :repo_url,        'https://github.com/edgeryders/discourse.git'
set :user,            'discourse'
set :deploy_to, "/home/discourse/#{fetch(:stage)}"

set :pty,             true
set :use_sudo,        false
set :deploy_via,      :remote_cache
set :ssh_options,     { forward_agent: true, user: fetch(:user), keys: %w(~/.ssh/id_rsa.pub) }

# https://github.com/seuros/capistrano-puma
set :puma_threads,    [4, 16]
set :puma_workers,    0
set :puma_conf, "#{shared_path}/config/puma.rb"
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.error.log"
set :puma_error_log,  "#{release_path}/log/puma.access.log"
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, false  # Change to true if using ActiveRecord



## Linked Files & Directories (Default None):
set :linked_files, fetch(:linked_files, []).push('config/discourse.conf', 'config/puma.rb')
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system', 'public/backups', 'public/uploads')

# set :linked_dirs,  %w{log tmp vendor/bundle public/assets public/backups public/uploads}

## Defaults:
# set :scm,           :git
# set :branch,        :master
# set :format,        :pretty
# set :log_level,     :debug
# set :keep_releases, 5
