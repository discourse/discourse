# frozen_string_literal: true

require "demon/base"

class Demon::Sidekiq < ::Demon::Base
  def self.prefix
    "sidekiq"
  end

  def self.after_fork(&blk)
    blk ? (@blk = blk) : @blk
  end

  # By default Sidekiq does a heartbeat check every 5 seconds. If the processes misses 20 heartbeat checks, we consider it
  # dead and kill the process.
  SIDEKIQ_HEARTBEAT_CHECK_MISS_THRESHOLD_SECONDS = 5.seconds * 20

  def self.heartbeat_check
    sidekiq_processes_for_current_hostname = {}

    Sidekiq::ProcessSet.new.each do |process|
      if process["hostname"] == HOSTNAME
        sidekiq_processes_for_current_hostname[process["pid"]] = process
      end
    end

    Demon::Sidekiq.demons.values.each do |daemon|
      next if !daemon.already_running?

      running_sidekiq_process = sidekiq_processes_for_current_hostname[daemon.pid]

      if !running_sidekiq_process ||
           (Time.now.to_i - running_sidekiq_process["beat"]) >
             SIDEKIQ_HEARTBEAT_CHECK_MISS_THRESHOLD_SECONDS
        Rails.logger.warn("Sidekiq heartbeat test failed for #{daemon.pid}, restarting")
        daemon.restart
      end
    end
  end

  SIDEKIQ_RSS_MEMORY_CHECK_INTERVAL_SECONDS = 30.minutes

  def self.rss_memory_check
    if defined?(@@last_sidekiq_rss_memory_check) && @@last_sidekiq_rss_memory_check &&
         @@last_sidekiq_rss_memory_check > Time.now.to_i - SIDEKIQ_RSS_MEMORY_CHECK_INTERVAL_SECONDS
      return @@last_sidekiq_rss_memory_check
    end

    Demon::Sidekiq.demons.values.each do |daemon|
      next if !daemon.already_running?

      daemon_rss_bytes = (`ps -o rss= -p #{daemon.pid}`.chomp.to_i || 0) * 1024

      if daemon_rss_bytes > max_allowed_sidekiq_rss_bytes
        Rails.logger.warn(
          "Sidekiq is consuming too much memory (using: %0.2fM) for '%s', restarting" %
            [(daemon_rss_bytes.to_f / 1.megabyte), HOSTNAME],
        )

        daemon.restart
      end
    end

    @@last_sidekiq_rss_memory_check = Time.now.to_i
  end

  DEFAULT_MAX_ALLOWED_SIDEKIQ_RSS_MEGABYTES = 500

  def self.max_allowed_sidekiq_rss_bytes
    [ENV["UNICORN_SIDEKIQ_MAX_RSS"].to_i, DEFAULT_MAX_ALLOWED_SIDEKIQ_RSS_MEGABYTES].max.megabytes
  end

  private

  def suppress_stdout
    false
  end

  def suppress_stderr
    false
  end

  def log_in_trap(message, level: :info)
    SignalTrapLogger.instance.log(@logger, message, level: level)
  end

  def after_fork
    Demon::Sidekiq.after_fork&.call
    SignalTrapLogger.instance.after_fork

    log("Loading Sidekiq in process id #{Process.pid}")
    require "sidekiq/cli"
    cli = Sidekiq::CLI.instance

    # Unicorn uses USR1 to indicate that log files have been rotated
    Signal.trap("USR1") { reopen_logs }

    Signal.trap("USR2") do
      sleep 1
      reopen_logs
    end

    options = ["-c", GlobalSetting.sidekiq_workers.to_s]

    [["critical", 8], ["default", 4], ["low", 2], ["ultra_low", 1]].each do |queue_name, weight|
      custom_queue_hostname = ENV["UNICORN_SIDEKIQ_#{queue_name.upcase}_QUEUE_HOSTNAME"]

      if !custom_queue_hostname || custom_queue_hostname.split(",").include?(Discourse.os_hostname)
        options << "-q"
        options << "#{queue_name},#{weight}"
      end
    end

    # Sidekiq not as high priority as web, in this environment it is forked so a web is very
    # likely running
    Discourse::Utils.execute_command("renice", "-n", "5", "-p", Process.pid.to_s)

    cli.parse(options)
    load Rails.root + "config/initializers/100-sidekiq.rb"
    cli.run
  rescue => error
    log(
      "Error encountered while starting Sidekiq: [#{error.class}] #{error.message}\n#{error.backtrace.join("\n")}",
      level: :error,
    )

    exit 1
  end

  private

  def reopen_logs
    begin
      log_in_trap("Sidekiq reopening logs...")
      Unicorn::Util.reopen_logs
      log_in_trap("Sidekiq done reopening logs...")
    rescue => error
      log_in_trap(
        "Error encountered while reopening logs: [#{error.class}] #{error.message}\n#{error.backtrace.join("\n")}",
        level: :error,
      )

      exit 1
    end
  end
end
