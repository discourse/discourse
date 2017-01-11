require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/postgresql_adapter'
require 'discourse'

class PostgreSQLFallbackHandler
  include Singleton

  def initialize
    @masters_down = {}
    @mutex = Mutex.new
  end

  def verify_master
    synchronize { return if @thread && @thread.alive? }

    @thread = Thread.new do
      while true do
        begin
          thread = Thread.new { initiate_fallback_to_master }
          thread.join
          break if synchronize { @masters_down.empty? }
          sleep 10
        ensure
          thread.kill
        end
      end
    end
  end

  def master_down?
    synchronize { @masters_down[namespace] }
  end

  def master_down=(args)
    synchronize { @masters_down[namespace] = args }
  end

  def master_up(namespace)
    synchronize { @masters_down.delete(namespace) }
  end

  def initiate_fallback_to_master
    @masters_down.keys.each do |key|
      RailsMultisite::ConnectionManagement.with_connection(key) do
        begin
          logger.warn "#{log_prefix}: Checking master server..."
          connection = ActiveRecord::Base.postgresql_connection(config)

          if connection.active?
            connection.disconnect!
            ActiveRecord::Base.clear_all_connections!
            logger.warn "#{log_prefix}: Master server is active. Reconnecting..."

            self.master_up(key)
            Discourse.disable_readonly_mode(Discourse::PG_READONLY_MODE_KEY)
          end
        rescue => e
          logger.warn "#{log_prefix}: Connection to master PostgreSQL server failed with '#{e.message}'"
        end
      end
    end
  end

  # Use for testing
  def setup!
    @masters_down = {}
  end

  private

  def config
    ActiveRecord::Base.connection_config
  end

  def logger
    Rails.logger
  end

  def log_prefix
    "#{self.class} [#{namespace}]"
  end

  def namespace
    RailsMultisite::ConnectionManagement.current_db
  end

  def synchronize
    @mutex.synchronize { yield }
  end
end

module ActiveRecord
  module ConnectionHandling
    def postgresql_fallback_connection(config)
      fallback_handler = ::PostgreSQLFallbackHandler.instance
      config = config.symbolize_keys

      if fallback_handler.master_down?
        fallback_handler.verify_master

        connection = postgresql_connection(config.dup.merge({
          host: config[:replica_host], port: config[:replica_port]
        }))

        verify_replica(connection)
        Discourse.enable_readonly_mode(Discourse::PG_READONLY_MODE_KEY)
      else
        begin
          connection = postgresql_connection(config)
        rescue PG::ConnectionBad => e
          fallback_handler.master_down = true
          fallback_handler.verify_master
          raise e
        end
      end

      connection
    end

    private

    def verify_replica(connection)
      value = connection.raw_connection.exec("SELECT pg_is_in_recovery()").values[0][0]
      raise "Replica database server is not in recovery mode." if value == 'f'
    end
  end
end
