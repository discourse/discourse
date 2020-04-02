# frozen_string_literal: true

module RailsMultisite
  class ConnectionManagement
    def self.safe_each_connection
      self.each_connection do |db|
        begin
          yield(db) if block_given?
        rescue => e
          STDERR.puts "URGENT: Failed to initialize site #{db}: "\
            "#{e.class} #{e.message}\n#{e.backtrace.join("\n")}"

          # the show must go on, don't stop startup if multisite fails
        end
      end
    end
  end

  class DiscoursePatches
    def self.config
      {
        db_lookup: lambda do |env|
          env["PATH_INFO"] == "/srv/status" ? "default" : nil
        end
      }
    end
  end
end

if Rails.configuration.multisite
  Rails.configuration.middleware.swap(
    RailsMultisite::Middleware,
    RailsMultisite::Middleware,
    RailsMultisite::DiscoursePatches.config
  )
end
