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
      begin
        connection = postgresql_connection(config)
      rescue PG::ConnectionBad => e
        connection = postgresql_connection(config.dup.merge({
          "host" => config["replica_host"], "port" => config["replica_port"]
        }))

        verify_replica(connection)

        Discourse.enable_readonly_mode if !Discourse.readonly_mode?

        start_connection_heartbeart(connection, config)
      end

      connection
    end

    private

    def verify_replica(connection)
      value = connection.raw_connection.exec("SELECT pg_is_in_recovery()").values[0][0]
      raise "Replica database server is not in recovery mode." if value == 'f'
    end

    def interval
      5
    end

    def start_connection_heartbeart(existing_connection, config)
      timer_task = Concurrent::TimerTask.new(execution_interval: interval) do |task|
        connection = postgresql_connection(config)

        if connection.active?
          existing_connection.disconnect!
          Discourse.disable_readonly_mode if Discourse.readonly_mode?
          task.shutdown
        end
      end

      timer_task.add_observer(TaskObserver.new)
      timer_task.execute
    end
  end
end
