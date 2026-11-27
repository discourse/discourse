# frozen_string_literal: true

require_relative "pending_work"

module Scheduler
  # ThreadPool manages a pool of worker threads that process tasks from a queue.
  # It maintains a minimum number of threads and can scale up to a maximum number
  # when there's more work to be done.
  #
  # Usage:
  #  pool = ThreadPool.new(min_threads: 0, max_threads: 4, idle_time: 0.1)
  #  pool.post { do_something }
  #  pool.stats (returns thread count, busy thread count, etc.)
  #
  #  pool.shutdown (do not accept new tasks)
  #  pool.wait_for_termination(timeout: 1) (optional timeout)

  class ThreadPool
    class ShutdownError < StandardError
    end

    def initialize(min_threads:, max_threads:, idle_time: nil)
      # 30 seconds is a reasonable default for idle time
      # it is particularly useful for the use case of:
      # ThreadPool.new(min_threads: 4, max_threads: 4)
      # operators would get confused about idle time cause why does it matter
      idle_time ||= 30
      raise ArgumentError, "min_threads must be 0 or larger" if min_threads < 0
      raise ArgumentError, "max_threads must be 1 or larger" if max_threads < 1
      raise ArgumentError, "max_threads must be >= min_threads" if max_threads < min_threads
      raise ArgumentError, "idle_time must be positive" if idle_time <= 0

      @min_threads = min_threads
      @max_threads = max_threads
      @idle_time = idle_time
      @shutdown = false
      @mutex = Mutex.new
      @mutex.synchronize { reset_execution_state }
    end

    def post(&block)
      reset_after_fork if @pid != Process.pid

      db = RailsMultisite::ConnectionManagement.current_db
      locale = I18n.locale
      wrapped_block = wrap_block(block, db, locale)

      PendingWork.enqueue do
        @mutex.synchronize do
          raise ShutdownError, "Cannot post work to a shutdown ThreadPool" if @shutdown
          spawn_thread if @threads.length == 0
          @queue << wrapped_block

          @new_work.signal
        end
      end
    end

    def wait_for_termination(timeout: nil)
      threads_to_join = nil
      @mutex.synchronize { threads_to_join = @threads.to_a }

      if timeout.nil?
        threads_to_join.each(&:join)
      else
        failed_to_shutdown = false

        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        threads_to_join.each do |thread|
          remaining_time = [deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0].max
          if !thread.join(remaining_time)
            Rails.logger.error "ThreadPool: Failed to join thread within timeout\n#{Array(thread.backtrace).join("\n")}"
            failed_to_shutdown = true
          end
        end

        if failed_to_shutdown
          discarded_tasks = 0
          @mutex.synchronize do
            @threads.each(&:kill)
            while (task = @queue.pop(timeout: 0))
              discarded_tasks += 1 if task != :shutdown
            end
          end
          discarded_tasks.times { PendingWork.finish }
          raise ShutdownError, "Failed to shutdown ThreadPool within timeout"
        end
      end
    end

    def shutdown
      @mutex.synchronize do
        return if @shutdown
        @shutdown = true
        @threads.length.times { @queue << :shutdown }
        @new_work.broadcast
      end
    end

    def shutdown?
      @mutex.synchronize { @shutdown }
    end

    def stats
      @mutex.synchronize do
        {
          thread_count: @threads.size,
          queued_tasks: @queue.size,
          shutdown: @shutdown,
          min_threads: @min_threads,
          max_threads: @max_threads,
          busy_thread_count: @busy_threads.size,
        }
      end
    end

    private

    def reset_after_fork
      @mutex.synchronize { reset_execution_state if @pid != Process.pid }
    end

    def reset_execution_state
      @threads = Set.new
      @busy_threads = Set.new
      @queue = Queue.new
      @new_work = ConditionVariable.new
      @min_threads.times { spawn_thread } if !@shutdown
      @pid = Process.pid
    end

    def wrap_block(block, db, locale)
      proc do
        RailsMultisite::ConnectionManagement.with_connection(db) do
          I18n.with_locale(locale) { block.call }
        end
      rescue StandardError => e
        Discourse.warn_exception(e, message: "Discourse Scheduler ThreadPool: Unhandled exception")
      end
    end

    def thread_loop
      loop do
        done = false
        work = nil

        @mutex.synchronize do
          # we may have already have work so no need
          # to wait for signals, this also handles the race
          # condition between spinning up threads and posting work
          work = @queue.pop(timeout: 0)
          if !work
            Thread.handle_interrupt(Object => :immediate) { @new_work.wait(@mutex, @idle_time) }
          end

          if !work && @queue.empty?
            done = @threads.count > @min_threads
          else
            work ||= @queue.pop

            if work == :shutdown
              work = nil
              done = true
            end
          end

          @busy_threads << Thread.current if work

          if !done && !@shutdown && work && @queue.length > 0 && @threads.length < @max_threads &&
               @busy_threads.length == @threads.length
            spawn_thread
          end

          @threads.delete(Thread.current) if done
        end

        break if done
        Thread.handle_interrupt(Object => :immediate, &work) if work
      ensure
        if work
          @mutex.synchronize { @busy_threads.delete(Thread.current) }
          PendingWork.finish
        end
      end
    end

    # Outside of constructor usage this is called from a synchronized block
    # we are already synchronized
    def spawn_thread
      thread = Thread.new { Thread.handle_interrupt(Object => :never) { thread_loop } }
      thread.abort_on_exception = true
      @threads << thread
    end
  end
end
