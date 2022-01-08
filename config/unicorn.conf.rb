# frozen_string_literal: true

# See http://unicorn.bogomips.org/Unicorn/Configurator.html

if (ENV["LOGSTASH_UNICORN_URI"] || "").length > 0
  require_relative '../lib/discourse_logstash_logger'
  require_relative '../lib/unicorn_logstash_patch'
  logger DiscourseLogstashLogger.logger(uri: ENV['LOGSTASH_UNICORN_URI'], type: :unicorn)
end

discourse_path = File.expand_path(File.expand_path(File.dirname(__FILE__)) + "/../")

# tune down if not enough ram
worker_processes (ENV["UNICORN_WORKERS"] || 3).to_i

working_directory discourse_path

# listen "#{discourse_path}/tmp/sockets/unicorn.sock"
listen ENV["UNICORN_LISTENER"] || "#{(ENV["UNICORN_BIND_ALL"] ? "" : "127.0.0.1:")}#{(ENV["UNICORN_PORT"] || 3000).to_i}"

if !File.exist?("#{discourse_path}/tmp/pids")
  FileUtils.mkdir_p("#{discourse_path}/tmp/pids")
end

# feel free to point this anywhere accessible on the filesystem
pid (ENV["UNICORN_PID_PATH"] || "#{discourse_path}/tmp/pids/unicorn.pid")

if ENV["RAILS_ENV"] != "production"
  logger Logger.new(STDOUT)
  # we want a longer timeout in dev cause first request can be really slow
  timeout (ENV["UNICORN_TIMEOUT"] && ENV["UNICORN_TIMEOUT"].to_i || 60)
else
  # By default, the Unicorn logger will write to stderr.
  # Additionally, some applications/frameworks log to stderr or stdout,
  # so prevent them from going to /dev/null when daemonized here:
  stderr_path "#{discourse_path}/log/unicorn.stderr.log"
  stdout_path "#{discourse_path}/log/unicorn.stdout.log"
  # nuke workers after 30 seconds instead of 60 seconds (the default)
  timeout 30
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

    # V8 does not support forking, make sure all contexts are disposed
    ObjectSpace.each_object(MiniRacer::Context) { |c| c.dispose }

    # get rid of rubbish so we don't share it
    # longer term we will use compact! here
    GC.start
    GC.start
    GC.start

    initialized = true

    supervisor = ENV['UNICORN_SUPERVISOR_PID'].to_i
    if supervisor > 0
      Thread.new do
        while true
          unless File.exist?("/proc/#{supervisor}")
            puts "Kill self supervisor is gone"
            Process.kill "TERM", Process.pid
          end
          sleep 2
        end
      end
    end

    sidekiqs = ENV['UNICORN_SIDEKIQS'].to_i
    if sidekiqs > 0
      server.logger.info "starting #{sidekiqs} supervised sidekiqs"

      require 'demon/sidekiq'
      Demon::Sidekiq.after_fork do
        DiscourseEvent.trigger(:sidekiq_fork_started)
      end

      Demon::Sidekiq.start(sidekiqs)

      Signal.trap("SIGTSTP") do
        STDERR.puts "#{Time.now}: Issuing stop to sidekiq"
        Demon::Sidekiq.stop
      end

      # Trap USR1, so we can re-issue to sidekiq workers
      # but chain the default unicorn implementation as well
      old_handler = Signal.trap("USR1") do
        Demon::Sidekiq.kill("USR1")
        old_handler.call
      end
    end

    if ENV['DISCOURSE_ENABLE_EMAIL_SYNC_DEMON'] == 'true'
      server.logger.info "starting up EmailSync demon"
      Demon::EmailSync.start
      Signal.trap("SIGTSTP") do
        STDERR.puts "#{Time.now}: Issuing stop to EmailSync"
        Demon::EmailSync.stop
      end
    end

    DiscoursePluginRegistry.demon_processes.each do |demon_class|
      server.logger.info "starting #{demon_class.prefix} demon"
      demon_class.start
    end

    class ::Unicorn::HttpServer
      alias :master_sleep_orig :master_sleep

      def max_sidekiq_rss
        rss = `ps -eo rss,args | grep sidekiq | grep -v grep | awk '{print $1}'`
          .split("\n")
          .map(&:to_i)
          .max

        rss ||= 0

        rss * 1024
      end

      def max_allowed_sidekiq_rss
        [ENV['UNICORN_SIDEKIQ_MAX_RSS'].to_i, 500].max.megabytes
      end

      def force_kill_rogue_sidekiq
        info = `ps -eo pid,rss,args | grep sidekiq | grep -v grep | awk '{print $1,$2}'`
        info.split("\n").each do |row|
          pid, mem = row.split(" ").map(&:to_i)
          if pid > 0 && (mem * 1024) > max_allowed_sidekiq_rss
            Rails.logger.warn "Detected rogue Sidekiq pid #{pid} mem #{mem * 1024}, killing"
            Process.kill("KILL", pid) rescue nil
          end
        end
      end

      def check_sidekiq_heartbeat
        @sidekiq_heartbeat_interval ||= 30.minutes
        @sidekiq_next_heartbeat_check ||= Time.now.to_i + @sidekiq_heartbeat_interval

        if @sidekiq_next_heartbeat_check < Time.now.to_i

          last_heartbeat = Jobs::RunHeartbeat.last_heartbeat
          restart = false

          sidekiq_rss = max_sidekiq_rss
          if sidekiq_rss > max_allowed_sidekiq_rss
            Rails.logger.warn("Sidekiq is consuming too much memory (using: %0.2fM) for '%s', restarting" % [(sidekiq_rss.to_f / 1.megabyte), ENV["DISCOURSE_HOSTNAME"]])
            restart = true
          end

          if last_heartbeat < Time.now.to_i - @sidekiq_heartbeat_interval
            STDERR.puts "Sidekiq heartbeat test failed, restarting"
            Rails.logger.warn "Sidekiq heartbeat test failed, restarting"

            restart = true
          end
          @sidekiq_next_heartbeat_check = Time.now.to_i + @sidekiq_heartbeat_interval

          if restart
            Demon::Sidekiq.restart
            sleep 10
            force_kill_rogue_sidekiq
          end
          Discourse.redis.close
        end
      end

      def max_email_sync_rss
        return 0 if Demon::EmailSync.demons.empty?

        email_sync_pids = Demon::EmailSync.demons.map { |uid, demon| demon.pid }
        return 0 if email_sync_pids.empty?

        rss = `ps -eo pid,rss,args | grep '#{email_sync_pids.join('|')}' | grep -v grep | awk '{print $2}'`
          .split("\n")
          .map(&:to_i)
          .max

        (rss || 0) * 1024
      end

      def max_allowed_email_sync_rss
        [ENV['UNICORN_EMAIL_SYNC_MAX_RSS'].to_i, 500].max.megabytes
      end

      def check_email_sync_heartbeat
        # Skip first check to let process warm up
        @email_sync_next_heartbeat_check ||= (Time.now + Demon::EmailSync::HEARTBEAT_INTERVAL).to_i

        return if @email_sync_next_heartbeat_check > Time.now.to_i
        @email_sync_next_heartbeat_check = (Time.now + Demon::EmailSync::HEARTBEAT_INTERVAL).to_i

        restart = false

        # Restart process if it does not respond anymore
        last_heartbeat_ago = Time.now.to_i - Discourse.redis.get(Demon::EmailSync::HEARTBEAT_KEY).to_i
        if last_heartbeat_ago > Demon::EmailSync::HEARTBEAT_INTERVAL.to_i
          STDERR.puts("EmailSync heartbeat test failed (last heartbeat was #{last_heartbeat_ago}s ago), restarting")
          restart = true
        end

        # Restart process if memory usage is too high
        email_sync_rss = max_email_sync_rss
        if email_sync_rss > max_allowed_email_sync_rss
          STDERR.puts("EmailSync is consuming too much memory (using: %0.2fM) for '%s', restarting" % [(email_sync_rss.to_f / 1.megabyte), ENV["DISCOURSE_HOSTNAME"]])
          restart = true
        end

        Demon::EmailSync.restart if restart
      end

      def master_sleep(sec)
        sidekiqs = ENV['UNICORN_SIDEKIQS'].to_i
        if sidekiqs > 0
          Demon::Sidekiq.ensure_running
          check_sidekiq_heartbeat
        end

        if ENV['DISCOURSE_ENABLE_EMAIL_SYNC_DEMON'] == 'true'
          Demon::EmailSync.ensure_running
          check_email_sync_heartbeat
        end

        DiscoursePluginRegistry.demon_processes.each do |demon_class|
          demon_class.ensure_running
        end

        master_sleep_orig(sec)
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
end
