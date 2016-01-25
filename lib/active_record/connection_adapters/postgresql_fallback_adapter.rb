require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/postgresql_adapter'
require 'discourse'
require 'concurrent'

class TaskObserver
  def update(time, result, ex)
    if result
      logger.info { "PG connection heartbeat successfully returned #{result}" }
    elsif ex.is_a?(Concurrent::TimeoutError)
      logger.warning { "PG connection heartbeat timed out".freeze }
    else
      if ex.message.include?("PG::UnableToSend")
        logger.info { "PG connection heartbeat: Master connection is not active.".freeze }
      else
        logger.error { "PG connection heartbeat failed with error: \"#{ex}\"" }
      end
    end
  end

  private

  def logger
    Rails.logger
  end
end

module ActiveRecord
  module ConnectionHandling
    def postgresql_fallback_connection(config)
      master_connection = postgresql_connection(config)

      replica_connection = postgresql_connection(config.dup.merge({
        host: config[:replica_host], port: config[:replica_port]
      }))
      verify_replica(replica_connection)

      klass = ConnectionAdapters::PostgreSQLFallbackAdapter.proxy_pass(master_connection.class)
      klass.new(master_connection, replica_connection, logger, config)
    end

    private

    def verify_replica(connection)
      value = connection.raw_connection.exec("SELECT pg_is_in_recovery()").values[0][0]
      raise "Replica database server is not in recovery mode." if value == 'f'
    end
  end

  module ConnectionAdapters
    class PostgreSQLFallbackAdapter < AbstractAdapter
      ADAPTER_NAME = "PostgreSQLFallback".freeze
      MAX_FAILURE = 5
      HEARTBEAT_INTERVAL = 5

      attr_reader :main_connection

      def self.all_methods(klass)
        methods = []

        (klass.ancestors - AbstractAdapter.ancestors).each do |_klass|
          %w(public protected private).map do |level|
            methods << _klass.send("#{level}_instance_methods", false)
          end
        end

        methods.flatten.uniq.sort
      end

      def self.proxy_pass(klass)
        Class.new(self) do
          (self.all_methods(klass) - self.all_methods(self)).each do |method|
            self.class_eval <<-EOF
              def #{method}(*args, &block)
                proxy_method(:#{method}, *args, &block)
              end
            EOF
          end
        end
      end

      def initialize(master_connection, replica_connection, logger, config)
        super(nil, logger, config)

        @master_connection = master_connection
        @main_connection = @master_connection
        @replica_connection = replica_connection
        @failure_count = 0
        load!
      end

      def proxy_method(method, *args, &block)
        @main_connection.send(method, *args, &block)
      rescue ActiveRecord::StatementInvalid => e
        if e.message.include?("PG::UnableToSend") && @main_connection == @master_connection
          @failure_count += 1

          if @failure_count == MAX_FAILURE
            Discourse.enable_readonly_mode if !Discourse.readonly_mode?
            @main_connection = @replica_connection
            load!
            connection_heartbeart(@master_connection)
            @failure_count = 0
          else
            proxy_method(method, *args, &block)
          end
        end

        raise e
      end

      private

      def load!
        @visitor = @main_connection.visitor
        @connection = @main_connection.raw_connection
      end

      def connection_heartbeart(connection, interval = HEARTBEAT_INTERVAL)
        timer_task = Concurrent::TimerTask.new(execution_interval: interval) do |task|
          connection.reconnect!

          if connection.active?
            @main_connection = connection
            load!
            Discourse.disable_readonly_mode if Discourse.readonly_mode?
            task.shutdown
          end
        end

        timer_task.add_observer(TaskObserver.new)
        timer_task.execute
      end
    end
  end
end
