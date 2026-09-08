# frozen_string_literal: true

require "demon/base"

class Demon::RailsAutospec < Demon::Base
  class << self
    def prefix
      "rails-autospec"
    end
  end

  def stop_signal
    "TERM"
  end

  private

  def after_fork
    require "rack"
    ENV["RAILS_ENV"] = "test"
    Rack::Server.start(config: "config.ru", AccessLog: [], Port: ENV["TEST_SERVER_PORT"] || 60_099)
  rescue => e
    STDERR.puts e.message
    STDERR.puts e.backtrace.join("\n")
    exit 1
  end
end
