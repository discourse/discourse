# frozen_string_literal: true

module Migrations
  module Database
    # Database operations can run together. Forking waits for all of them to finish.
    # Nested operations are tracked by thread because streams use fibers.
    class LifecycleLock
      def initialize
        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @readers = Hash.new(0)
        @writer = nil
        @waiting_writers = 0
      end

      # @return the block's result
      # @raise [Lifecycle::UnsafeForkError] when called on the thread that holds
      #   {#exclusive}
      def synchronize
        thread = Thread.current
        @mutex.synchronize do
          if @writer == thread
            raise Lifecycle::UnsafeForkError, "Database access inside a fork batch"
          end
          @condition.wait(@mutex) while @writer || (@waiting_writers > 0 && @readers[thread].zero?)
          @readers[thread] += 1
        end
        begin
          yield
        ensure
          @mutex.synchronize do
            @readers.delete(thread) if (@readers[thread] -= 1).zero?
            @condition.broadcast
          end
        end
      end

      # @return the block's result
      # @raise [Lifecycle::UnsafeForkError] when the current thread is inside
      #   {#synchronize} or already holds the lock
      def exclusive
        thread = Thread.current
        @mutex.synchronize do
          if @readers[thread] > 0 || @writer == thread
            raise Lifecycle::UnsafeForkError, "Cannot fork inside a database operation"
          end
          @waiting_writers += 1
          begin
            @condition.wait(@mutex) while @writer || @readers.any?
            @writer = thread
          ensure
            @waiting_writers -= 1
            @condition.broadcast
          end
        end
        begin
          yield
        ensure
          @mutex.synchronize do
            @writer = nil
            @condition.broadcast
          end
        end
      end
    end
  end
end
