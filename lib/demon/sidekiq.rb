# frozen_string_literal: true

require "demon/base"

class Demon::Sidekiq < ::Demon::Base
  cattr_accessor :logger

  def self.prefix
    "sidekiq"
  end

  def self.after_fork(&blk)
    blk ? (@blk = blk) : @blk
  end

  def self.format(message)
    "[#{Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%6N")} ##{Process.pid}] #{message}"
  end

  def self.log(message, level: :info)
    # We use an IO pipe and log messages using the logger in a seperate thread to avoid the `log writing failed. can't be called from trap context`
    # error message that is raised when trying to log from within a `Signal.trap` block.
    if logger
      if !defined?(@logger_read_pipe)
        @logger_read_pipe, @logger_write_pipe = IO.pipe

        @logger_thread =
          Thread.new do
            begin
              while readable_io = IO.select([@logger_read_pipe])
                logger.public_send(level, readable_io.first[0].gets.strip)
              end
            rescue => e
              STDOUT.puts self.format(
                            "Error in Sidekiq demon logger thread: #{e.message}\n#{e.backtrace.join("\n")}",
                          )
            end
          end
      end

      @logger_write_pipe.puts(message)
    else
      STDOUT.puts self.format(message)
    end
  end

  private

  def suppress_stdout
    false
  end

  def suppress_stderr
    false
  end

  def log(message, level: :info)
    self.class.log(message, level:)
  end

  def after_fork
    Demon::Sidekiq.after_fork&.call

    log("Loading Sidekiq in process id #{Process.pid}")
    require "sidekiq/cli"
    cli = Sidekiq::CLI.instance

    # Unicorn uses USR1 to indicate that log files have been rotated
    Signal.trap("USR1") do
      log("Sidekiq reopening logs...")
      Unicorn::Util.reopen_logs
      log("Sidekiq done reopening logs...")
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
  rescue => e
    STDERR.puts e.message
    STDERR.puts e.backtrace.join("\n")
    exit 1
  end
end
