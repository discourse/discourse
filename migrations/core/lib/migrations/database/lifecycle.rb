# frozen_string_literal: true

module Migrations
  module Database
    # Tracks open database connections and prepares them for forks.
    module Lifecycle
      # Raised when a fork would leave a connection in an unknown state.
      class UnsafeForkError < StandardError
      end

      # Raised when a connection could not be reopened after a fork.
      class RecoveryError < StandardError
      end

      @lock = LifecycleLock.new
      @mutex = Mutex.new
      @connections = []

      class << self
        # A fork waits until all synchronized blocks are finished.
        # @return the block's result
        # @raise [UnsafeForkError] when called inside {.with_fork} on the forking thread
        def synchronize(&block)
          @lock.synchronize(&block)
        end

        # @param connection [ManagedConnection]
        # @return [void]
        def register(connection)
          @mutex.synchronize { @connections << connection }
        end

        # @param connection [ManagedConnection]
        # @return [void]
        def unregister(connection)
          @mutex.synchronize { @connections.delete(connection) }
        end

        # @return [Integer] how many connections are open in this process
        def connection_count
          @mutex.synchronize { @connections.size }
        end

        # @return the block's result
        # @raise [UnsafeForkError] if a connection cannot be forked
        # @raise [RecoveryError] if a connection cannot be reopened
        def with_fork
          @lock.exclusive do
            connections = @mutex.synchronize { @connections.dup }
            connections.each(&:check_before_fork!)
            prepared_connections = []
            begin
              connections.each do |connection|
                prepared_connections << connection
                connection.prepare_fork!
              end
              yield
            ensure
              restore_errors = []
              prepared_connections.reverse_each do |connection|
                connection.restore_after_fork!
              rescue Exception => error
                restore_errors << error
              end
              if restore_errors.any?
                raise RecoveryError,
                      "Restoring database connections failed: #{restore_errors.map(&:message).join("; ")}"
              end
            end
          end
        end

        # Discards all inherited connections in a forked worker.
        # @return [void]
        def after_fork_child
          @lock = LifecycleLock.new
          @mutex = Mutex.new
          @connections.each(&:discard_after_fork!)
          @connections.clear
        end
      end
    end
  end
end
