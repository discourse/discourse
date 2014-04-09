# See https://devcenter.heroku.com/articles/rails-unicorn
# and http://unicorn.bogomips.org/Unicorn/Configurator.html

discourse_path = File.expand_path(File.expand_path(File.dirname(__FILE__)) + "/../")

# tune down if not enough ram
worker_processes Integer(ENV['UNICORN_WORKERS'] || 2)

working_directory discourse_path

# nuke workers after 30 seconds instead of 60 seconds (the default)
timeout 30

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

  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end

  ActiveRecord::Base.connection.disconnect!
  $redis.client.disconnect


  #TODO
  # at this point we want to fork out sidekiq, it will let us reuse the shared memory

  # The following is only recommended for memory/DB-constrained
  # installations.  It is not needed if your system can house
  # twice as many worker_processes as you have configured.
  #
  # # This allows a new master process to incrementally
  # # phase out the old master process with SIGTTOU to avoid a
  # # thundering herd (especially in the "preload_app false" case)
  # # when doing a transparent upgrade.  The last worker spawned
  # # will then kill off the old master process with a SIGQUIT.
  # old_pid = "#{server.config[:pid]}.oldbin"
  # if old_pid != server.pid
  #   begin
  #     sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
  #     Process.kill(sig, File.read(old_pid).to_i)
  #   rescue Errno::ENOENT, Errno::ESRCH
  #   end
  # end
  #
  # Throttle the master from forking too quickly by sleeping.  Due
  # to the implementation of standard Unix signal handlers, this
  # helps (but does not completely) prevent identical, repeated signals
  # from being lost when the receiving process is busy.
  # sleep 1
end

after_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT'
  end
  ActiveRecord::Base.establish_connection
  $redis.client.reconnect
  Rails.cache.reconnect
  MessageBus.after_fork
end
