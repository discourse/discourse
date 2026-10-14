# frozen_string_literal: true

module Scheduler
  module ForkDrain
    class << self
      def reset_after_fork
        @pid = Process.pid
        @mutex = Mutex.new
        @changed = ConditionVariable.new
        @pending = 0
        @fork_thread = nil
      end

      def register
        reset_after_fork if @pid != Process.pid
        @mutex.synchronize do
          @changed.wait(@mutex) while @fork_thread
          @pending += 1
        end
      end

      def complete
        @mutex.synchronize do
          @pending -= 1
          @changed.broadcast if @pending.zero?
        end
      end

      def pending
        @mutex.synchronize { @pending }
      end

      def drain(timeout: nil)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout if timeout
        @mutex.synchronize do
          while @pending > 0 || (@fork_thread && @fork_thread != Thread.current)
            remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC) if deadline
            return false if remaining && remaining <= 0
            @changed.wait(@mutex, remaining)
          end
          @fork_thread = Thread.current
        end
        true
      end

      def resume
        @mutex.synchronize do
          return unless @fork_thread == Thread.current
          @fork_thread = nil
          @changed.broadcast
        end
      end
    end

    reset_after_fork
  end
end
