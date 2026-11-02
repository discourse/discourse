# frozen_string_literal: true

module Migrations
  module Database
    # Keeps a database connection in a valid state when workers are forked.
    class ManagedConnection
      # Raised when the connection is not open.
      class UnavailableError < StandardError
      end

      # Raised when the connection is already in use.
      class BusyError < StandardError
      end

      # Raised when a worker uses an inherited connection.
      class DiscardedError < UnavailableError
      end

      # Opening cannot overlap with a fork. The connection may exist before the
      # constructor returns it to Ruby.
      # @param driver [Object] opens and configures the database connection
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
        unless %i[forbid detach close_reopen].include?(@policy)
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

      # @yieldparam connection [Object] the driver's database connection
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

      # @return [void]
      # @raise [Lifecycle::UnsafeForkError] if the connection cannot be forked
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

      # @return [void]
      def discard_after_fork!
        @driver.detach(@connection) if @connection
        @connection = nil
        @state = :discarded
        @mutex = Mutex.new
        @operation_depth = 0
      end

      # @param owner [Object] the thread, fiber or stream running the operation;
      #   the same owner may nest operations
      # @return [Object] the driver's database connection
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
