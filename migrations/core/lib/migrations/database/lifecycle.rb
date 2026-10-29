# frozen_string_literal: true

module Migrations
  module Database
    module Lifecycle
      class UnsafeForkError < StandardError
      end

      class RecoveryError < StandardError
      end

      @gate = LifecycleGate.new
      @mutex = Mutex.new
      @connections = []

      class << self
        def synchronize(&block)
          @gate.synchronize(&block)
        end

        def register(connection)
          @mutex.synchronize { @connections << connection }
        end

        def unregister(connection)
          @mutex.synchronize { @connections.delete(connection) }
        end

        def connection_count
          @mutex.synchronize { @connections.size }
        end

        def with_fork
          @gate.exclusive do
            connections = @mutex.synchronize { @connections.dup }
            connections.each(&:validate_fork!)
            prepared = []
            begin
              connections.each do |connection|
                prepared << connection
                connection.prepare_fork!
              end
              yield
            ensure
              errors = []
              prepared.reverse_each do |connection|
                connection.restore_after_fork!
              rescue Exception => error
                errors << error
              end
              if errors.any?
                raise RecoveryError,
                      "Restoring database connections failed: #{errors.map(&:message).join("; ")}"
              end
            end
          end
        end

        def after_fork_child
          @gate = LifecycleGate.new
          @mutex = Mutex.new
          @connections.each(&:discard_after_fork!)
          @connections.clear
        end
      end
    end
  end
end
