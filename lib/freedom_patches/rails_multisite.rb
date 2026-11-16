# frozen_string_literal: true

module RailsMultisite
  class ConnectionManagement
    # Long-running processes (sidekiq, the scheduler) capture the multisite
    # config in memory at boot and never re-read it, so sites provisioned or
    # decommissioned out-of-band leave every job that iterates all sites
    # failing until the process restarts. Callers that run work against the
    # site list should check for config changes first.
    def self.reload_if_changed
      cm = ConnectionManagement.instance
      return false if cm.config_filename.blank?
      cm.reload_if_changed
    end

    def reload_if_changed
      mtime =
        begin
          File.mtime(config_filename)
        rescue SystemCallError
          nil
        end
      return false if mtime.nil? || mtime == @config_mtime

      reload
      @config_mtime = mtime
      Rails.logger.info("Reloaded multisite config after change to #{config_filename}")
      true
    rescue StandardError => e
      # A malformed or partially written config must not take down the job
      # loop: keep running on the previous spec cache and retry next call.
      Rails.logger.warn("Failed to reload multisite config: #{e.class} #{e.message}")
      false
    end

    def self.each_active_connection(&blk)
      if ENV["RAILS_DB"]
        blk.call(current_db)
      else
        each_connection(&blk)
      end
    end

    def self.safe_each_connection
      each_active_connection do |db|
        yield(db) if block_given?
      rescue PG::ConnectionBad, PG::UnableToSend, PG::ServerError
        break if !defined?(RailsFailover::ActiveRecord)
        break if db == RailsMultisite::ConnectionManagement::DEFAULT

        reading_role = :"#{db}_#{ActiveRecord.reading_role}"
        spec = RailsMultisite::ConnectionManagement.connection_spec(db: db)
        handler = ActiveRecord::Base.connection_handler

        RailsFailover::ActiveRecord.establish_reading_connection(
          handler,
          spec.to_hash,
          role: reading_role,
        )
        ActiveRecord::Base.connected_to(role: reading_role) { yield(db) if block_given? }
      rescue => e
        STDERR.puts "URGENT: Failed to initialize site #{db}: " \
                      "#{e.class} #{e.message}\n#{e.backtrace.join("\n")}"
        # the show must go on, don't stop startup if multisite fails
      end
    end
  end

  class DiscoursePatches
    def self.config
      { db_lookup: lambda { |env| env["PATH_INFO"] == "/srv/status" ? "default" : nil } }
    end
  end
end
