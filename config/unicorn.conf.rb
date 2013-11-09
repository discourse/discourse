# See http://unicorn.bogomips.org/Unicorn/Configurator.html

discourse_path = File.expand_path(File.expand_path(File.dirname(__FILE__)) + "/../")

# tune down if not enough ram
worker_processes (ENV["UNICORN_WORKERS"] || 3).to_i

working_directory discourse_path

# listen "#{discourse_path}/tmp/sockets/unicorn.sock"
listen 3000

# nuke workers after 30 seconds instead of 60 seconds (the default)
timeout 30

# feel free to point this anywhere accessible on the filesystem
pid "#{discourse_path}/tmp/pids/unicorn.pid"

# By default, the Unicorn logger will write to stderr.
# Additionally, some applications/frameworks log to stderr or stdout,
# so prevent them from going to /dev/null when daemonized here:
stderr_path "#{discourse_path}/log/unicorn.stderr.log"
stdout_path "#{discourse_path}/log/unicorn.stdout.log"

# important for Ruby 2.0
preload_app true

# Enable this flag to have unicorn test client connections by writing the
# beginning of the HTTP headers before calling the application.  This
# prevents calling the application for connections that have disconnected
# while queued.  This is only guaranteed to detect clients on the same
# host unicorn runs on, and unlikely to detect disconnects even on a
# fast LAN.
check_client_connection false

initialized = false
before_fork do |server, worker|

  unless initialized
    # load up the yaml for the localization bits, in master process
    I18n.t(:posts)
    # get rid of rubbish so we don't share it
    GC.start
  end

  ActiveRecord::Base.connection.disconnect!
  $redis.client.disconnect


  # Throttle the master from forking too quickly by sleeping.  Due
  # to the implementation of standard Unix signal handlers, this
  # helps (but does not completely) prevent identical, repeated signals
  # from being lost when the receiving process is busy.
  sleep 1
end

after_fork do |server, worker|
  ActiveRecord::Base.establish_connection
  $redis.client.reconnect
  Rails.cache.reconnect
  MessageBus.after_fork
end
