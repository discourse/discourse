# frozen_string_literal: true

module Migrations
  module Database
    # Operations may overlap, but a fork waits for all lifecycle work and SQLite
    # operations. Ownership follows the thread so streaming fibers can nest calls.
    class LifecycleGate
      def initialize
        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @readers = Hash.new(0)
        @writer = nil
        @waiting_writers = 0
      end

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
