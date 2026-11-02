# frozen_string_literal: true

module Migrations
  module Database
    # The registry of open {ManagedConnection}s and the fork protocol for them.
    # `ForkManager` is the only caller of {.with_fork} and {.after_fork_child};
    # connections register themselves when they open.
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
        # Runs work that a fork must not interrupt: opening or closing a
        # connection, or an operation on a `:close_reopen` connection. Blocks may
        # overlap with each other; a pending fork waits for all of them.
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

        # Runs a fork batch: waits for {.synchronize} blocks to finish, checks every
        # connection, closes the `:close_reopen` ones, yields while the forks
        # happen, and reopens the closed connections afterwards. No connection can
        # be opened, closed or used with `:close_reopen` until the block returns.
        # @return the block's result
        # @raise [UnsafeForkError] if a connection cannot be forked, see
        #   {ManagedConnection#validate_fork!}
        # @raise [RecoveryError] if a connection could not be reopened; an error
        #   from the block becomes its cause
        def with_fork
          @lock.exclusive do
            connections = @mutex.synchronize { @connections.dup }
            connections.each(&:validate_fork!)
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

        # Resets the registry in a forked child. Every inherited connection is
        # discarded, so the child has to open its own.
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
