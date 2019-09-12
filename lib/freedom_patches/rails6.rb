# frozen_string_literal: true

# see: https://github.com/rails/rails/pull/36949#issuecomment-530698779
#
# Without this patch each time we close a DB connection we spin a thread

module ::ActiveRecord
  module ConnectionAdapters
    class AbstractAdapter
      class StaticThreadLocalVar
        attr_reader :value

        def initialize(value)
          @value = value
        end

        def bind(value)
          raise "attempting to change immutable local var" if value != @value
          if block_given?
            yield
          end
        end
      end

      # we have no choice but to perform an aggressive patch here
      # if we simply hook the method we will still call a finalizer
      # on Concurrent::ThreadLocalVar

      def initialize(connection, logger = nil, config = {}) # :nodoc:
        super()

        @connection          = connection
        @owner               = nil
        @instrumenter        = ActiveSupport::Notifications.instrumenter
        @logger              = logger
        @config              = config
        @pool                = ActiveRecord::ConnectionAdapters::NullPool.new
        @idle_since          = Concurrent.monotonic_time
        @visitor = arel_visitor
        @statements = build_statement_pool
        @lock = ActiveSupport::Concurrency::LoadInterlockAwareMonitor.new

        if self.class.type_cast_config_to_boolean(config.fetch(:prepared_statements) { true })
          @prepared_statement_status = Concurrent::ThreadLocalVar.new(true)
          @visitor.extend(DetermineIfPreparableVisitor)
        else
          #@prepared_statement_status = Concurrent::ThreadLocalVar.new(false)
          @prepared_statement_status = StaticThreadLocalVar.new(false)
        end

        @advisory_locks_enabled = self.class.type_cast_config_to_boolean(
          config.fetch(:advisory_locks, true)
        )
      end
    end
  end
end
