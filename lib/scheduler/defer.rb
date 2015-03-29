module Scheduler
  module Deferrable
    def initialize
      @async = !Rails.env.test?
      @queue = Queue.new
      @mutex = Mutex.new
      @paused = false
      @thread = nil
    end

    def pause
      stop!
      @paused = true
    end

    def resume
      @paused = false
    end

    # for test
    def async=(val)
      @async = val
    end

    def later(desc = nil, db=RailsMultisite::ConnectionManagement.current_db, &blk)
      if @async
        start_thread unless (@thread && @thread.alive?) || @paused
        @queue << [db, blk, desc]
      else
        blk.call
      end
    end

    def stop!
      @thread.kill if @thread && @thread.alive?
      @thread = nil
    end

    # test only
    def stopped?
      !(@thread && @thread.alive?)
    end

    def do_all_work
      while !@queue.empty?
        do_work(_non_block=true)
      end
    end

    private

    def start_thread
      @mutex.synchronize do
        return if @thread && @thread.alive?
        @thread = Thread.new {
          while true
            do_work
          end
        }
      end
    end

    # using non_block to match Ruby #deq
    def do_work(non_block=false)
      db, job, desc = @queue.deq(non_block)
      begin
        RailsMultisite::ConnectionManagement.establish_connection(db: db) if db
        job.call
      rescue => ex
        Discourse.handle_job_exception(ex, {message: "Running deferred code '#{desc}'"})
      end
    rescue => ex
      Discourse.handle_job_exception(ex, {message: "Processing deferred code queue"})
    ensure
      ActiveRecord::Base.connection_handler.clear_active_connections!
    end

  end

  class Defer

    module Unicorn
      def process_client(client)
        Defer.pause
        super(client)
        Defer.do_all_work
        Defer.resume
      end
    end

    extend Deferrable
    initialize
  end
end
