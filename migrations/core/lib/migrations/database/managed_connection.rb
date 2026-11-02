# frozen_string_literal: true

module Migrations
  module Database
    # One native database handle plus the bookkeeping that makes worker forks safe.
    # The driver opens, configures and closes the handle and names its fork policy;
    # the README section "Database connections and fork safety" describes the
    # policies. Every operation runs in {#with}, which marks the handle as busy for
    # the calling thread or fiber. {Lifecycle} calls the `*_fork!` methods around
    # each fork. {PostgresStream} uses {#start_operation} and {#finish_operation}
    # to keep the handle busy between calls to `next`.
    class ManagedConnection
      # Raised when the connection is not open: it was closed, is suspended for a
      # fork, failed to reopen, or was discarded in a worker.
      class UnavailableError < StandardError
      end

      # Raised when another thread, fiber or stream has an operation running on
      # the connection.
      class BusyError < StandardError
      end

      # Raised in a worker that uses a connection inherited from its parent.
      class DiscardedError < UnavailableError
      end

      # Opens a connection. Opening never overlaps with a fork, because a native
      # constructor can open its socket before Ruby gets the handle.
      # @param driver [Object] opens and configures the native handle, see
      #   {Drivers::Postgres} and {Drivers::Sqlite}
      # @yieldparam connection [ManagedConnection] closed when the block returns
      # @return [ManagedConnection] the open connection, or the block's result
      def self.open(driver)
        connection = Lifecycle.synchronize { new(driver) }
        return connection unless block_given?

        begin
          yield connection
        ensure
          connection.close
        end
      end

      def initialize(driver)
        @driver = driver
        @policy = driver.respond_to?(:fork_policy) ? driver.fork_policy : :forbid
        unless %i[forbid discard close_reopen].include?(@policy)
          raise ArgumentError, "Unknown fork policy: #{@policy.inspect}"
        end

        @pid = Process.pid
        @mutex = Mutex.new
        @operation_depth = 0
        @state = :closed

        Lifecycle.register(self)
        begin
          open!
        rescue Exception
          close!
          raise
        end
      end
      private_class_method :new

      # Runs one operation on the native handle. The same thread (`:close_reopen`)
      # or fiber (other policies) may nest calls; every other caller gets a
      # {BusyError} until the block returns. With `:close_reopen`, a fork also waits
      # for the block, because the handle is closed before forking.
      # @yieldparam connection [Object] the driver's native handle
      # @return the block's result
      # @raise [BusyError] if another thread, fiber or stream is using the connection
      # @raise [UnavailableError] if the connection is not open
      # @raise [Lifecycle::UnsafeForkError] with `:close_reopen`, when called inside
      #   a fork batch on the forking thread
      def with(&block)
        if close_reopen?
          Lifecycle.synchronize { with_connection(&block) }
        else
          with_connection(&block)
        end
      end

      # Closes the native handle. A connection discarded in a worker is already
      # gone, so closing it does nothing.
      # @return [void]
      # @raise [BusyError] if an operation or stream is still running
      def close
        return if @state == :discarded

        Lifecycle.synchronize { close! }
      end

      # @return [Boolean] true unless the connection is open in the current process
      def closed?
        @state != :open || @pid != Process.pid
      end

      # Checks that forking is safe for this connection: it must be open, the
      # forking thread or fiber must not be inside an operation, the policy must
      # allow forks, and the driver gets to inspect the handle. Called by
      # {Lifecycle.with_fork} before the forks.
      # @return [void]
      # @raise [Lifecycle::UnsafeForkError]
      def validate_fork!
        unless @state == :open
          raise Lifecycle::UnsafeForkError, "#{@driver.class} connection is #{@state}"
        end

        if @operation_depth > 0 && @operation_owner == current_owner
          raise Lifecycle::UnsafeForkError, "Cannot fork inside an active database operation"
        end

        if @policy == :forbid
          raise Lifecycle::UnsafeForkError,
                "#{@driver.class} has no approved fork policy; close it before forking"
        end

        @driver.validate_fork!(@connection) if close_reopen?
      end

      # Closes the handle before a fork when the policy is `:close_reopen`; other
      # policies keep it open. The connection is suspended until
      # {#restore_after_fork!}. Called by {Lifecycle.with_fork}.
      # @return [void]
      def prepare_fork!
        return unless close_reopen?

        begin
          @driver.close(@connection)
          @connection = nil
          @state = :suspended
        rescue Exception
          @state = :failed
          raise
        end
      end

      # Reopens a connection that {#prepare_fork!} suspended. If reopening fails,
      # the connection stays failed and every later operation raises
      # {UnavailableError}. Called by {Lifecycle.with_fork} after the forks.
      # @return [void]
      def restore_after_fork!
        return unless @state == :suspended

        begin
          open!
        rescue Exception
          @driver.close(@connection) if @connection
          @connection = nil
          @state = :failed
          raise
        end
      end

      # Passes the handle inherited by a forked child to the driver's `discard`, so
      # the child cannot touch the parent's session. Called by
      # {Lifecycle.after_fork_child}.
      # @return [void]
      def discard_after_fork!
        @driver.discard(@connection) if @connection
        @connection = nil
        @state = :discarded
        @mutex = Mutex.new
        @operation_depth = 0
      end

      # Marks the connection as busy for `owner` and returns the native handle.
      # Streams use this to keep the handle between calls to `next`; everything
      # else goes through {#with}. Each call needs a matching {#finish_operation}.
      # @param owner [Object] the thread, fiber or stream running the operation;
      #   the same owner may nest operations
      # @return [Object] the driver's native handle
      # @raise [UnavailableError] if the connection is not open
      # @raise [BusyError] if a different owner has an operation running
      # @raise [DiscardedError] in a worker that inherited the connection
      def start_operation(owner)
        @mutex.synchronize do
          check_owner!
          raise UnavailableError, "Database connection is #{@state}" unless @state == :open

          if @operation_depth > 0 && @operation_owner != owner
            raise BusyError, "Database connection already has an active operation"
          end

          @operation_owner = owner
          @operation_depth += 1
          @connection
        end
      end

      # Ends an operation started with {#start_operation}.
      # @return [void]
      def finish_operation
        @mutex.synchronize { @operation_depth -= 1 }
      end

      private

      def close_reopen?
        @policy == :close_reopen
      end

      def current_owner
        close_reopen? ? Thread.current : Fiber.current
      end

      def open!
        @connection = @driver.open
        @driver.configure(@connection)
        @state = :open
      end

      def close!
        @mutex.synchronize do
          check_owner!
          if @operation_depth > 0
            raise BusyError, "Cannot close a connection with an active operation"
          end

          @driver.close(@connection) if @connection
          @connection = nil
          @state = :closed
          Lifecycle.unregister(self)
        end
      end

      def with_connection
        connection = start_operation(current_owner)

        begin
          yield connection
        ensure
          finish_operation
        end
      end

      def check_owner!
        if @pid != Process.pid || @state == :discarded
          raise DiscardedError,
                "Database connection belongs to another process; open a new connection in the worker"
        end
      end
    end
  end
end
