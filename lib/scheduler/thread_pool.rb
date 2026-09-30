# frozen_string_literal: true

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

    @paused = false

    class << self
      def paused?
        @paused
      end

      # Stops every pool in this process from starting queued tasks and waits
      # for running ones to finish, so the process can fork without copying a
      # task mid-way. Tasks posted meanwhile wait until resume.
      def pause
        @paused = true
        pools = ObjectSpace.each_object(self).to_a
        pools.each(&:pause)
        sleep 0.05 while pools.any?(&:running?)
      end

      def resume
        return if !@paused
        @paused = false
        ObjectSpace.each_object(self, &:resume)
      end
    end

    def self.idle?
      ObjectSpace.each_object(self).all?(&:idle?)
    end

    # Waits up to timeout seconds for every pool in this process to finish its
    # work. Returns whether they did.
    def self.wait_for_idle(timeout:)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      until idle?
        return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        sleep 0.05
      end
      true
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

      @threads = Set.new
      @busy_threads = Set.new

      @queue = Queue.new
      @mutex = Mutex.new
      @new_work = ConditionVariable.new
      @shutdown = false
      @paused = self.class.paused?
      @pid = Process.pid

      # Initialize minimum number of threads
      @min_threads.times { spawn_thread }
    end

    def post(&block)
      reset_after_fork if @pid != Process.pid
      raise ShutdownError, "Cannot post work to a shutdown ThreadPool" if shutdown?

      db = RailsMultisite::ConnectionManagement.current_db
      locale = I18n.locale
      wrapped_block = wrap_block(block, db, locale)

      @mutex.synchronize do
        @queue << wrapped_block
        spawn_thread if @threads.length == 0

        @new_work.signal
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
          remaining_time = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          break if remaining_time <= 0
          if !thread.join(remaining_time)
            Rails.logger.error "ThreadPool: Failed to join thread within timeout\n#{thread.backtrace.join("\n")}"
            failed_to_shutdown = true
          end
        end

        if failed_to_shutdown
          @mutex.synchronize { @threads.each(&:kill) }
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

    def pause
      @mutex.synchronize { @paused = true } if @pid == Process.pid
    end

    def resume
      # A forked process starts afresh on the next post.
      return @paused = false if @pid != Process.pid

      @mutex.synchronize do
        @paused = false
        spawn_thread if @threads.empty? && !@queue.empty? && !@shutdown
        @new_work.broadcast
      end
    end

    def running?
      return false if @pid != Process.pid

      @mutex.synchronize { @busy_threads.any?(&:alive?) }
    end

    def idle?
      # A forked process has none of the parent's threads.
      return true if @pid != Process.pid

      @mutex.synchronize do
        @threads.none?(&:alive?) || (@queue.empty? && @busy_threads.none?(&:alive?))
      end
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

    # A forked process inherits this pool's state but not its threads, and
    # queued tasks keep running in the parent, so start again empty.
    def reset_after_fork
      @pid = Process.pid
      @threads = Set.new
      @busy_threads = Set.new
      @queue = Queue.new
      @mutex = Mutex.new
      @new_work = ConditionVariable.new
      @paused = false
      @min_threads.times { spawn_thread } if !@shutdown
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
      done = false
      while !done
        work = nil

        @mutex.synchronize do
          @new_work.wait(@mutex) while @paused && !@shutdown

          # we may have already have work so no need
          # to wait for signals, this also handles the race
          # condition between spinning up threads and posting work
          work = @queue.pop(timeout: 0)
          @new_work.wait(@mutex, @idle_time) if !work
          # Paused while waiting: check again at the top of the loop.
          next if !work && @paused && !@shutdown

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

          if !done && work && @queue.length > 0 && @threads.length < @max_threads &&
               @busy_threads.length == @threads.length
            spawn_thread
          end

          @threads.delete(Thread.current) if done
        end

        if work
          begin
            work.call
          ensure
            @mutex.synchronize { @busy_threads.delete(Thread.current) }
          end
        end
      end
    end

    # Outside of constructor usage this is called from a synchronized block
    # we are already synchronized
    def spawn_thread
      thread = Thread.new { thread_loop }
      thread.abort_on_exception = true
      @threads << thread
    end
  end
end
