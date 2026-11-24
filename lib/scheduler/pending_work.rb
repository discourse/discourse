# frozen_string_literal: true

module Scheduler
  module PendingWork
    @mutex = Mutex.new
    @idle = ConditionVariable.new
    @count = 0
    @pid = Process.pid

    class << self
      def enqueue
        Thread.handle_interrupt(Object => :never) do
          add
          enqueued = false
          begin
            result = yield
            enqueued = true
            result
          ensure
            finish if !enqueued
          end
        end
      end

      def run
        Thread.handle_interrupt(Object => :never) do
          add
          begin
            Thread.handle_interrupt(Object => :immediate) { yield }
          ensure
            finish
          end
        end
      end

      def finish
        synchronize do
          @count -= 1
          @idle.broadcast if @count.zero?
        end
      end

      def when_idle(timeout:)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        synchronize do
          while @count > 0
            remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
            return false if remaining <= 0
            @idle.wait(@mutex, remaining)
          end

          yield
        end
      end

      private

      def add
        synchronize { @count += 1 }
      end

      def synchronize
        @mutex.synchronize do
          if @pid != Process.pid
            @idle = ConditionVariable.new
            @count = 0
            @pid = Process.pid
          end
          yield
        end
      end
    end
  end
end
