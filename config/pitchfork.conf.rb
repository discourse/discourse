# frozen_string_literal: true

discourse_path = File.expand_path(File.expand_path(File.dirname(__FILE__)) + "/../")
enable_logstash_logger = ENV["ENABLE_LOGSTASH_LOGGER"] == "1"
unicorn_stderr_path = "#{discourse_path}/log/unicorn.stderr.log"

if enable_logstash_logger
  require_relative "../lib/discourse_logstash_logger"
  require_relative "../lib/pitchfork_logstash_patch"
  FileUtils.touch(unicorn_stderr_path) if !File.exist?(unicorn_stderr_path)
  logger DiscourseLogstashLogger.logger(
           logdev: unicorn_stderr_path,
           type: :unicorn,
           customize_event: lambda { |event| event["@timestamp"] = ::Time.now.utc },
         )
else
  logger Logger.new(STDOUT)
end

worker_processes (ENV["UNICORN_WORKERS"] || 3).to_i

# stree-ignore
listen ENV["UNICORN_LISTENER"] || "#{(ENV["UNICORN_BIND_ALL"] ? "" : "127.0.0.1:")}#{(ENV["UNICORN_PORT"] || 3000).to_i}"

if ENV["RAILS_ENV"] == "production"
  # nuke workers after 30 seconds instead of 60 seconds (the default)
  timeout 30
else
  # we want a longer timeout in dev cause first request can be really slow
  timeout(ENV["UNICORN_TIMEOUT"] && ENV["UNICORN_TIMEOUT"].to_i || 60)
end

check_client_connection false

before_fork { |server| Discourse.redis.close }

after_mold_fork do |server, mold|
  if mold.generation.zero?
    Discourse.preload_rails!

    supervisor = ENV["UNICORN_SUPERVISOR_PID"].to_i

    if supervisor > 0
      Thread.new do
        while true
          unless File.exist?("/proc/#{supervisor}")
            server.logger.error "Kill self, supervisor is gone"
            Process.kill "TERM", Process.pid
          end
          sleep 2
        end
      end
    end
  end

  Discourse.redis.close
  Discourse.before_fork
end

after_worker_fork do |server, worker|
  DiscourseEvent.trigger(:web_fork_started)
  Discourse.after_fork
  SignalTrapLogger.instance.after_fork
end

before_service_worker_ready do |server, service_worker|
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
end
