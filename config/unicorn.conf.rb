# See http://unicorn.bogomips.org/Unicorn/Configurator.html

# enable out of band gc out of the box, it is low risk and improves perf a lot
ENV['UNICORN_ENABLE_OOBGC'] ||= "1"

discourse_path = File.expand_path(File.expand_path(File.dirname(__FILE__)) + "/../")

# tune down if not enough ram
worker_processes (ENV["UNICORN_WORKERS"] || 3).to_i

working_directory discourse_path

# listen "#{discourse_path}/tmp/sockets/unicorn.sock"
listen (ENV["UNICORN_PORT"] || 3000).to_i

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

    # load up all models and schema
    (ActiveRecord::Base.connection.tables - %w[schema_migrations]).each do |table|
      table.classify.constantize.first rescue nil
    end

    # router warm up
    Rails.application.routes.recognize_path('abc') rescue nil

    # get rid of rubbish so we don't share it
    GC.start

    initialized = true

    supervisor = ENV['UNICORN_SUPERVISOR_PID'].to_i
    if supervisor > 0
      Thread.new do
        while true
          unless File.exists?("/proc/#{supervisor}")
            puts "Kill self supervisor is gone"
            Process.kill "TERM", Process.pid
          end
          sleep 2
        end
      end
    end

    sidekiqs = ENV['UNICORN_SIDEKIQS'].to_i
    if sidekiqs > 0
      puts "Starting up #{sidekiqs} supervised sidekiqs"

      require 'demon/sidekiq'

      Demon::Sidekiq.start(sidekiqs)

      class ::Unicorn::HttpServer
        alias :master_sleep_orig :master_sleep

        def check_sidekiq_heartbeat
          @sidekiq_heartbeat_interval ||= 30.minutes
          @sidekiq_next_heartbeat_check ||= Time.new.to_i + @sidekiq_heartbeat_interval

          if @sidekiq_next_heartbeat_check < Time.new.to_i
            last_heartbeat = Jobs::RunHeartbeat.last_heartbeat
            if last_heartbeat < Time.new.to_i - @sidekiq_heartbeat_interval
              STDERR.puts "Sidekiq heartbeat test failed, restarting"
              puts "Sidekiq heartbeat test failed, restarting"

              Demon::Sidekiq.restart
            end
            @sidekiq_next_heartbeat_check = Time.new.to_i + @sidekiq_heartbeat_interval
          end
        end

        def master_sleep(sec)
          Demon::Sidekiq.ensure_running
          check_sidekiq_heartbeat

          master_sleep_orig(sec)
        end
      end
    end

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
  Discourse.after_fork
end
