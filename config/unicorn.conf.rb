# frozen_string_literal: true

# See http://unicorn.bogomips.org/Unicorn/Configurator.html
discourse_path = File.expand_path(File.expand_path(File.dirname(__FILE__)) + "/../")

enable_logstash_logger = ENV["ENABLE_LOGSTASH_LOGGER"] == "1"
unicorn_stderr_path = "#{discourse_path}/log/unicorn.stderr.log"
unicorn_stdout_path = "#{discourse_path}/log/unicorn.stdout.log"

if enable_logstash_logger
  require_relative "../lib/discourse_logstash_logger"
  require_relative "../lib/unicorn_logstash_patch"
  FileUtils.touch(unicorn_stderr_path) if !File.exist?(unicorn_stderr_path)
  logger DiscourseLogstashLogger.logger(
           logdev: unicorn_stderr_path,
           type: :unicorn,
           customize_event: lambda { |event| event["@timestamp"] = ::Time.now.utc },
         )
else
  logger Logger.new(STDOUT)
end

# tune down if not enough ram
worker_processes (ENV["UNICORN_WORKERS"] || 3).to_i

working_directory discourse_path

# listen "#{discourse_path}/tmp/sockets/unicorn.sock"

# stree-ignore
listen ENV["UNICORN_LISTENER"] || "#{(ENV["UNICORN_BIND_ALL"] ? "" : "127.0.0.1:")}#{(ENV["UNICORN_PORT"] || 3000).to_i}"

FileUtils.mkdir_p("#{discourse_path}/tmp/pids") if !File.exist?("#{discourse_path}/tmp/pids")

# feel free to point this anywhere accessible on the filesystem
pid(ENV["UNICORN_PID_PATH"] || "#{discourse_path}/tmp/pids/unicorn.pid")

if ENV["RAILS_ENV"] == "production"
  # By default, the Unicorn logger will write to stderr.
  # Additionally, some applications/frameworks log to stderr or stdout,
  # so prevent them from going to /dev/null when daemonized here:
  stderr_path unicorn_stderr_path
  stdout_path unicorn_stdout_path

  # nuke workers after 30 seconds instead of 60 seconds (the default)
  timeout 30
else
  # we want a longer timeout in dev cause first request can be really slow
  timeout(ENV["UNICORN_TIMEOUT"] && ENV["UNICORN_TIMEOUT"].to_i || 60)
end

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
    Discourse.preload_rails!
    Discourse.before_fork

    initialized = true

    supervisor = ENV["UNICORN_SUPERVISOR_PID"].to_i

    if supervisor > 0
      Thread.new do
        while true
          unless File.exist?("/proc/#{supervisor}")
            server.logger.error "Kill self supervisor is gone"
            Process.kill "TERM", Process.pid
          end
          sleep 2
        end
      end
    end

    sidekiqs = ENV["UNICORN_SIDEKIQS"].to_i

    if sidekiqs > 0
      server.logger.info "starting #{sidekiqs} supervised sidekiqs"

      require "demon/sidekiq"
      Demon::Sidekiq.after_fork { DiscourseEvent.trigger(:sidekiq_fork_started) }
      Demon::Sidekiq.start(sidekiqs, logger: server.logger)

      if Discourse.enable_sidekiq_logging?
        # Trap USR1, so we can re-issue to sidekiq workers
        # but chain the default unicorn implementation as well
        old_handler =
          Signal.trap("USR1") do
            old_handler.call

            # We have seen Sidekiq processes getting stuck in production sporadically when log rotation happens.
            # The cause is currently unknown but we suspect that it is related to the Unicorn master process and
            # Sidekiq demon processes reopening logs at the same time as we noticed that Unicorn worker processes only
            # reopen logs after the Unicorn master process is done. To workaround the problem, we are adding an arbitrary
            # delay of 1 second to Sidekiq's log reopeing procedure. The 1 second delay should be
            # more than enough for the Unicorn master process to finish reopening logs.
            Demon::Sidekiq.kill("USR2")
          end
      end
    end

    enable_email_sync_demon = ENV["DISCOURSE_ENABLE_EMAIL_SYNC_DEMON"] == "true"

    if enable_email_sync_demon
      server.logger.info "starting up EmailSync demon"
      Demon::EmailSync.start(1, logger: server.logger)
    end

    DiscoursePluginRegistry.demon_processes.each do |demon_class|
      server.logger.info "starting #{demon_class.prefix} demon"
      demon_class.start(1, logger: server.logger)
    end

    Thread.new do
      while true
        begin
          sleep 60

          if sidekiqs > 0
            Demon::Sidekiq.ensure_running
            Demon::Sidekiq.heartbeat_check
            Demon::Sidekiq.rss_memory_check
          end

          if enable_email_sync_demon
            Demon::EmailSync.ensure_running
            Demon::EmailSync.check_email_sync_heartbeat
          end

          DiscoursePluginRegistry.demon_processes.each { |demon_class| demon_class.ensure_running }
        rescue => e
          Rails.logger.warn(
            "Error in demon processes heartbeat check: #{e}\n#{e.backtrace.join("\n")}",
          )
        end
      end
    end

    class ::Unicorn::HttpServer
      # Original source: https://github.com/defunkt/unicorn/blob/6c9c442fb6aa12fd871237bc2bb5aec56c5b3538/lib/unicorn/http_server.rb#L477-L496
      def murder_lazy_workers
        next_sleep = @timeout - 1
        now = time_now.to_i
        @workers.dup.each_pair do |wpid, worker|
          tick = worker.tick
          0 == tick and next # skip workers that haven't processed any clients
          diff = now - tick
          tmp = @timeout - diff

          # START MONKEY PATCH
          if tmp < 2 && !worker.instance_variable_get(:@timing_out_logged)
            logger.error do
              "worker=#{worker.nr} PID:#{wpid} running too long (#{diff}s), sending USR2 to dump thread backtraces"
            end

            worker.instance_variable_set(:@timing_out_logged, true)
            kill_worker(:USR2, wpid)
          end
          # END MONKEY PATCH

          if tmp >= 0
            next_sleep > tmp and next_sleep = tmp
            next
          end
          next_sleep = 0
          logger.error "worker=#{worker.nr} PID:#{wpid} timeout " \
                         "(#{diff}s > #{@timeout}s), killing"

          kill_worker(:KILL, wpid) # take no prisoners for timeout violations
        end
        next_sleep <= 0 ? 1 : next_sleep
      end
    end
  end

  Discourse.redis.close

  # Throttle the master from forking too quickly by sleeping.  Due
  # to the implementation of standard Unix signal handlers, this
  # helps (but does not completely) prevent identical, repeated signals
  # from being lost when the receiving process is busy.
  sleep 1 if !Rails.env.development?
end

after_fork do |server, worker|
  DiscourseEvent.trigger(:web_fork_started)
  Discourse.after_fork
  SignalTrapLogger.instance.after_fork

  Signal.trap("USR2") do
    message = <<~MSG
    Unicorn worker received USR2 signal indicating it is about to timeout, dumping backtrace for main thread
    #{Thread.current.backtrace&.join("\n")}
    MSG

    SignalTrapLogger.instance.log(Rails.logger, message, level: :warn)
  end
end
