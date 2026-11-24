# frozen_string_literal: true
require "weakref"
require_relative "pending_work"

module Scheduler
  module Deferrable
    DEFAULT_TIMEOUT = 90
    STATS_CACHE_SIZE = 100

    attr_reader :async

    def initialize
      @async = !Rails.env.test?
      @timeout = DEFAULT_TIMEOUT
      @mutex = Mutex.new
      reset_execution_state
    end

    def reset_after_fork
      return if @pid == Process.pid

      @mutex.synchronize { reset_execution_state if @pid != Process.pid }
    end

    def timeout=(t)
      @mutex.synchronize { @timeout = t }
    end

    def length
      @queue.size
    end

    def stats
      @stats_mutex.synchronize { @stats.to_a }
    end

    def pause
      stop!
      @paused = true
    end

    def resume
      reset_after_fork if @pid != Process.pid
      @paused = false
    end

    # for test and sidekiq
    def async=(val)
      @async = val
    end

    def later(
      desc = nil,
      db = RailsMultisite::ConnectionManagement.current_db,
      force: true,
      current_user: nil,
      &blk
    )
      reset_after_fork if @pid != Process.pid
      @stats_mutex.synchronize do
        stats = (@stats[desc] ||= { queued: 0, finished: 0, duration: 0, errors: 0 })
        stats[:queued] += 1
      end

      if @async
        start_thread if !@thread&.alive? && !@paused
        PendingWork.enqueue do
          @queue.push({ site: db, user: current_user, db: db, job: blk, desc: desc }, force: force)
        end
      else
        PendingWork.run(&blk)
      end
    end

    def stop!(finish_work: false)
      if finish_work
        @finish = true
        @queue.push({ finish: true }, force: true)
        @thread&.join
      end
      @thread.kill if @thread&.alive?
      @thread = nil
      @reactor&.stop
      @reactor = nil
    end

    # test only
    def stopped?
      !@thread&.alive?
    end

    def do_all_work
      do_work(non_block = true) while !@queue.empty?
    end

    # For tests: runs blocks passed to #later after the yielded block returns,
    # rather than during.
    def capture_later
      captured = []
      define_singleton_method(:later) { |*, **, &blk| captured << blk }
      yield
      captured.shift.call until captured.empty?
    ensure
      singleton_class.remove_method(:later)
    end

    private

    def reset_execution_state
      @queue =
        WorkQueue::ThreadSafeWrapper.new(
          WorkQueue::FairQueue.new(:site, 500) do
            WorkQueue::FairQueue.new(:user, 100) { WorkQueue::BoundedQueue.new(50) }
          end,
        )
      @stats_mutex = Mutex.new
      @thread = nil
      @reactor = nil
      @stats = LruRedux::ThreadSafeCache.new(STATS_CACHE_SIZE)
      @finish = false
      @paused = false
      @pid = Process.pid
    end

    def start_thread
      @mutex.synchronize do
        return if @thread&.alive?

        Thread.handle_interrupt(Object => :never) do
          @reactor ||=
            Thread
              .new { Thread.handle_interrupt(Object => :immediate) { MessageBus::TimerThread.new } }
              .value

          @thread =
            Thread.new do
              Thread.handle_interrupt(Object => :immediate) do
                Thread.current.abort_on_exception = true if Rails.env.test?
                do_work while !@finish || !@queue.empty?
              end
            end
        end
      end
    end

    # using non_block to match Ruby #deq
    def do_work(non_block = false)
      Thread.handle_interrupt(Object => :never) do
        task = Thread.handle_interrupt(Object => :on_blocking) { @queue.shift(block: !non_block) }
        return if !task || task[:finish]

        begin
          Thread.handle_interrupt(Object => :immediate) { process_task(task, non_block) }
        ensure
          PendingWork.finish
        end
      end
    rescue => ex
      Discourse.handle_job_exception(ex, message: "Processing deferred code queue")
    end

    def process_task(task, non_block)
      db, job, desc = task.values_at(:db, :job, :desc)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      db ||= RailsMultisite::ConnectionManagement::DEFAULT

      RailsMultisite::ConnectionManagement.with_connection(db) do
        warning_job =
          @reactor.queue(@timeout) do
            Rails.logger.error "'#{desc}' is still running after #{@timeout} seconds on db #{db}, this process may need to be restarted!"
          end if !non_block
        job.call
      rescue => ex
        @stats_mutex.synchronize do
          stats = @stats[desc]
          stats[:errors] += 1 if stats
        end
        Discourse.handle_job_exception(ex, message: "Running deferred code '#{desc}'")
      ensure
        warning_job&.cancel
      end
    ensure
      if ActiveRecord::Base.connection&.verify!
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
      @stats_mutex.synchronize do
        stats = @stats[desc]
        if stats
          stats[:finished] += 1
          stats[:duration] += Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        end
      end
    end
  end

  class Defer
    extend Deferrable
    initialize
  end
end
