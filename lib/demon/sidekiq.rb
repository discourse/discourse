# frozen_string_literal: true

require "demon/base"

class Demon::Sidekiq < ::Demon::Base

  def self.prefix
    "sidekiq"
  end

  def self.after_fork(&blk)
    blk ? (@blk = blk) : @blk
  end

  private

  def suppress_stdout
    false
  end

  def suppress_stderr
    false
  end

  def after_fork
    Demon::Sidekiq.after_fork&.call

    puts "Loading Sidekiq in process id #{Process.pid}"
    require 'sidekiq/cli'
    # CLI will close the logger, if we have one set we can be in big
    # trouble, if STDOUT is closed in our process all sort of weird
    # will ensue, resetting the logger ensures it will reinit correctly
    # parent process is in charge of the file anyway.
    Sidekiq.logger = nil
    cli = Sidekiq::CLI.instance

    options = ["-c", GlobalSetting.sidekiq_workers.to_s]

    [['critical', 8], ['default', 4], ['low', 2], ['ultra_low', 1]].each do |queue_name, weight|
      custom_queue_hostname = ENV["UNICORN_SIDEKIQ_#{queue_name.upcase}_QUEUE_HOSTNAME"]

      if !custom_queue_hostname || custom_queue_hostname.split(',').include?(`hostname`.strip)
        options << "-q"
        options << "#{queue_name},#{weight}"
      end
    end

    # Sidekiq not as high priority as web, in this environment it is forked so a web is very
    # likely running
    Discourse::Utils.execute_command('renice', '-n', '5', '-p', Process.pid.to_s)

    cli.parse(options)
    load Rails.root + "config/initializers/100-sidekiq.rb"
    cli.run
  rescue => e
    STDERR.puts e.message
    STDERR.puts e.backtrace.join("\n")
    exit 1
  end

end
