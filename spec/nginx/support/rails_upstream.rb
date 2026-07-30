# frozen_string_literal: true

require_relative "nginx_test_probe"

module Nginx
  module Support
    class RailsUpstream
      def self.shared
        @shared ||= new
      end

      attr_reader :port, :probe

      def initialize
        @probe = NginxTestProbe.new(Rails.application)
      end

      def start
        probe.clear
        return self if @server

        @server =
          Capybara::Server.new(
            probe,
            host: Capybara.server_host,
            port: nil,
            reportable_errors: Capybara.server_errors,
          ).boot
        @port = @server.port
        self
      end

      # Capybara owns the server thread and keeps it alive for the test process.
      # `shared` ensures the nginx specs create only one such server per worker.
      def stop
      end
    end
  end
end
