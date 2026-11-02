# frozen_string_literal: true

module Migrations
  module Database
    class ManagedConnection
      class UnavailableError < StandardError
      end

      class BusyError < StandardError
      end

      class DiscardedError < UnavailableError
      end

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

      def with(&block)
        if close_reopen?
          Lifecycle.synchronize { with_connection(&block) }
        else
          with_connection(&block)
        end
      end

      def close
        return if @state == :discarded

        Lifecycle.synchronize { close! }
      end

      def closed?
        @state != :open || @pid != Process.pid
      end

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

      def discard_after_fork!
        @driver.discard(@connection) if @connection
        @connection = nil
        @state = :discarded
        @mutex = Mutex.new
        @operation_depth = 0
      end

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
