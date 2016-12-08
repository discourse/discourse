require "demon/base"

class Demon::Sidekiq < Demon::Base

  def self.prefix
    "sidekiq"
  end

  private

  def suppress_stdout
    false
  end

  def suppress_stderr
    false
  end

  def after_fork
    STDERR.puts "Loading Sidekiq in process id #{Process.pid}"
    require 'sidekiq/cli'
    # CLI will close the logger, if we have one set we can be in big
    # trouble, if STDOUT is closed in our process all sort of weird
    # will ensue, resetting the logger ensures it will reinit correctly
    # parent process is in charge of the file anyway.
    Sidekiq::Logging.logger = nil
    cli = Sidekiq::CLI.instance
    cli.parse(["-c", GlobalSetting.sidekiq_workers.to_s, "-q", "critical,4", "-q", "default,2", "-q", "low"])

    load Rails.root + "config/initializers/100-sidekiq.rb"
    cli.run
  rescue => e
    STDERR.puts e.message
    STDERR.puts e.backtrace.join("\n")
    exit 1
  end

end
