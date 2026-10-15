# frozen_string_literal: true

module Scheduler
  module ForkDrain
    class << self
      def reset_after_fork
        return if @pid == Process.pid
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

      def wait_for_idle(timeout:)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        @mutex.synchronize do
          while @pending > 0
            remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
            return false if remaining <= 0
            @changed.wait(@mutex, remaining)
          end
        end
        true
      end

      def drain
        @mutex.synchronize do
          while @pending > 0 || (@fork_thread && @fork_thread != Thread.current)
            @changed.wait(@mutex)
          end
          @fork_thread = Thread.current
        end
      end

      def resume
        reset_after_fork if @pid != Process.pid
        @mutex.synchronize do
          return if @fork_thread&.alive? && @fork_thread != Thread.current
          @fork_thread = nil
          @changed.broadcast
        end
      end
    end

    reset_after_fork
  end
end
