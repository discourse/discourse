# frozen_string_literal: true
require "weakref"

module Scheduler
  module Deferrable
    DEFAULT_TIMEOUT = 90
    STATS_CACHE_SIZE = 100

    attr_reader :async

    def initialize
      @async = !Rails.env.test?
      @queue =
        WorkQueue::ThreadSafeWrapper.new(
          WorkQueue::FairQueue.new(:site, 500) do
            WorkQueue::FairQueue.new(:user, 100) { WorkQueue::BoundedQueue.new(50) }
          end,
        )

      @mutex = Mutex.new
      @stats_mutex = Mutex.new
      @paused = false
      @thread = nil
      @reactor = nil
      @timeout = DEFAULT_TIMEOUT
      @stats = LruRedux::ThreadSafeCache.new(STATS_CACHE_SIZE)
      @finish = false
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
      @stats_mutex.synchronize do
        stats = (@stats[desc] ||= { queued: 0, finished: 0, duration: 0, errors: 0 })
        stats[:queued] += 1
      end

      if @async
        start_thread if !@thread&.alive? && !@paused
        @queue.push({ site: db, user: current_user, db: db, job: blk, desc: desc }, force: force)
      else
        blk.call
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

    private

    def start_thread
      @mutex.synchronize do
        @reactor = MessageBus::TimerThread.new if !@reactor
        @thread =
          Thread.new do
            @thread.abort_on_exception = true if Rails.env.test?
            do_work while (!@finish || !@queue.empty?)
          end if !@thread&.alive?
      end
    end

    # using non_block to match Ruby #deq
    def do_work(non_block = false)
      db, job, desc, finish = @queue.shift(block: !non_block).values_at(:db, :job, :desc, :finish)

      return if finish

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      db ||= RailsMultisite::ConnectionManagement::DEFAULT

      RailsMultisite::ConnectionManagement.with_connection(db) do
        begin
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
      end
    rescue => ex
      Discourse.handle_job_exception(ex, message: "Processing deferred code queue")
    ensure
      if ActiveRecord::Base.connection
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end
      if start
        @stats_mutex.synchronize do
          stats = @stats[desc]
          if stats
            stats[:finished] += 1
            stats[:duration] += Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
          end
        end
      end
    end
  end

  class Defer
    extend Deferrable
    initialize
  end
end
