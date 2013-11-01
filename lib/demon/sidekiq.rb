require "demon/base"

class Demon::Sidekiq < Demon::Base

  def self.prefix
    "sidekiq"
  end

  private

  def after_fork
    require 'sidekiq/cli'
    # Reload initializer cause it needs to run after sidekiq/cli was required
    load Rails.root + "config/initializers/sidekiq.rb"
    cli = Sidekiq::CLI.instance
    cli.parse([])
    cli.run
  rescue => e
    STDERR.puts e.message
    STDERR.puts e.backtrace.join("\n")
    exit 1
  end

end
