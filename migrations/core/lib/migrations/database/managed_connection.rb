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
        @quiesce = @policy == :close_reopen
        @pid = Process.pid
        @mutex = Mutex.new
        @depth = 0
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
        if @quiesce
          Lifecycle.synchronize { with_lease(&block) }
        else
          with_lease(&block)
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
        if @depth > 0 && @lease_owner == (@quiesce ? Thread.current : Fiber.current)
          raise Lifecycle::UnsafeForkError, "Cannot fork inside an active database operation"
        end
        if @policy == :forbid
          raise Lifecycle::UnsafeForkError,
                "#{@driver.class} has no approved fork policy; close it before forking"
        end
        @driver.validate_fork!(@native) if @policy == :close_reopen
      end

      def prepare_fork!
        return unless @policy == :close_reopen
        begin
          @driver.close(@native)
          @native = nil
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
          @driver.close(@native) if @native
          @native = nil
          @state = :failed
          raise
        end
      end

      def discard_after_fork!
        @driver.discard(@native) if @native
        @native = nil
        @state = :discarded
        @mutex = Mutex.new
        @depth = 0
      end

      # Streams reserve the protocol once, including between calls to #next.
      def checkout(owner)
        @mutex.synchronize do
          check_owner!
          raise UnavailableError, "Database connection is #{@state}" unless @state == :open
          if @depth > 0 && @lease_owner != owner
            raise BusyError, "Database connection already has an active operation"
          end
          @lease_owner = owner
          @depth += 1
          @native
        end
      end

      def checkin
        @mutex.synchronize { @depth -= 1 }
      end

      private

      def open!
        @native = @driver.open
        @driver.configure(@native)
        @state = :open
      end

      def close!
        @mutex.synchronize do
          check_owner!
          raise BusyError, "Cannot close a connection with an active operation" if @depth > 0
          @driver.close(@native) if @native
          @native = nil
          @state = :closed
          Lifecycle.unregister(self)
        end
      end

      def with_lease
        native = checkout(@quiesce ? Thread.current : Fiber.current)
        begin
          yield native
        ensure
          checkin
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
