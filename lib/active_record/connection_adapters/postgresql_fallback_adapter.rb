require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/postgresql_adapter'
require 'discourse'

class PostgreSQLFallbackHandler
  include Singleton

  attr_reader :running
  attr_accessor :master

  def initialize
    @master = true
    @running = false
    @mutex = Mutex.new
  end

  def verify_master
    @mutex.synchronize do
      return if @running || recently_checked?
      @running = true
    end

    Thread.new do
      begin
        logger.warn "#{self.class}: Checking master server..."
        connection = ActiveRecord::Base.postgresql_connection(config)

        if connection.active?
          connection.disconnect!
          logger.warn "#{self.class}: Master server is active. Reconnecting..."
          ActiveRecord::Base.establish_connection(config)
          Discourse.disable_readonly_mode
          @master = true
        end
      rescue => e
        if e.message.include?("could not connect to server")
          logger.warn "#{self.class}: Connection to master PostgreSQL server failed with '#{e.message}'"
        else
          raise e
        end
      ensure
        @mutex.synchronize do
          @last_check = Time.zone.now
          @running = false
        end
      end
    end
  end

  private

  def config
    ActiveRecord::Base.configurations[Rails.env]
  end

  def logger
    Rails.logger
  end

  def recently_checked?
    if @last_check
      Time.zone.now <= (@last_check + 5.seconds)
    else
      false
    end
  end
end

module ActiveRecord
  module ConnectionHandling
    def postgresql_fallback_connection(config)
      fallback_handler = ::PostgreSQLFallbackHandler.instance
      config = config.symbolize_keys

      if !fallback_handler.master && !fallback_handler.running
        connection = postgresql_connection(config.dup.merge({
          host: config[:replica_host], port: config[:replica_port]
        }))

        verify_replica(connection)
        Discourse.enable_readonly_mode
      else
        begin
          connection = postgresql_connection(config)
        rescue PG::ConnectionBad => e
          fallback_handler.master = false
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

  module ConnectionAdapters
    class PostgreSQLAdapter
      set_callback :checkout, :before, :switch_back?

      private

      def fallback_handler
        @fallback_handler ||= ::PostgreSQLFallbackHandler.instance
      end

      def switch_back?
        if !fallback_handler.master && !fallback_handler.running
          fallback_handler.verify_master
        end
      end
    end
  end
end
