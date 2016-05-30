require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/postgresql_adapter'
require 'discourse'

class PostgreSQLFallbackHandler
  include Singleton

  def initialize
    @master = {}
    @running = {}
    @mutex = {}
    @last_check = {}

    setup!
  end

  def verify_master
    @mutex[namespace].synchronize do
      return if running || recently_checked?
      @running[namespace] = true
    end

    current_namespace = namespace
    Thread.new do
      RailsMultisite::ConnectionManagement.with_connection(current_namespace) do
        begin
          logger.warn "#{log_prefix}: Checking master server..."
          connection = ActiveRecord::Base.postgresql_connection(config)

          if connection.active?
            connection.disconnect!
            ActiveRecord::Base.clear_all_connections!
            logger.warn "#{log_prefix}: Master server is active. Reconnecting..."

            if namespace == RailsMultisite::ConnectionManagement::DEFAULT
              ActiveRecord::Base.establish_connection(config)
            else
              RailsMultisite::ConnectionManagement.establish_connection(db: namespace)
            end

            Discourse.disable_readonly_mode
            self.master = true
          end
        rescue => e
          if e.message.include?("could not connect to server")
            logger.warn "#{log_prefix}: Connection to master PostgreSQL server failed with '#{e.message}'"
          else
            raise e
          end
        ensure
          @mutex[namespace].synchronize do
            @last_check[namespace] = Time.zone.now
            @running[namespace] = false
          end
        end
      end
    end
  end

  def master
    @master[namespace]
  end

  def master=(args)
    @master[namespace] = args
  end

  def running
    @running[namespace]
  end

  def setup!
    RailsMultisite::ConnectionManagement.all_dbs.each do |db|
      @master[db] = true
      @running[db] = false
      @mutex[db] = Mutex.new
      @last_check[db] = nil
    end
  end

  def verify?
    !master && !running
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

  def recently_checked?
    if @last_check[namespace]
      Time.zone.now <= (@last_check[namespace] + 5.seconds)
    else
      false
    end
  end

  def namespace
    RailsMultisite::ConnectionManagement.current_db
  end
end

module ActiveRecord
  module ConnectionHandling
    def postgresql_fallback_connection(config)
      fallback_handler = ::PostgreSQLFallbackHandler.instance
      config = config.symbolize_keys

      if fallback_handler.verify?
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
        fallback_handler.verify_master if fallback_handler.verify?
      end
    end
  end
end
