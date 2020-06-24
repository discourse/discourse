# frozen_string_literal: true

module RailsMultisite
  class ConnectionManagement
    def self.safe_each_connection
      self.each_connection do |db|
        begin
          yield(db) if block_given?
        rescue PG::ConnectionBad, PG::UnableToSend, PG::ServerError
          break if !defined?(RailsFailover::ActiveRecord)
          break if db == RailsMultisite::ConnectionManagement::DEFAULT

          reading_role = :"#{db}_#{ActiveRecord::Base.reading_role}"
          spec = RailsMultisite::ConnectionManagement.connection_spec(db: db)

          ActiveRecord::Base.connection_handlers[reading_role] ||= begin
            handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
            RailsFailover::ActiveRecord.establish_reading_connection(handler, spec)
            handler
          end

          ActiveRecord::Base.connected_to(role: reading_role) do
            yield(db) if block_given?
          end
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
