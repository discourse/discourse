module Scheduler
  module Deferrable
    def initialize
      @async = !Rails.env.test?
      @queue = Queue.new
      @mutex = Mutex.new
      @thread = nil
      start_thread

    end

    # for test
    def async=(val)
      @async = val
    end

    def later(desc = nil, &blk)
      if @async
        start_thread unless @thread.alive?
        @queue << [RailsMultisite::ConnectionManagement.current_db, blk, desc]
      else
        blk.call
      end
    end

    def stop!
      @thread.kill
    end

    # test only
    def stopped?
      !@thread.alive?
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

    def do_work
      db, job, desc = @queue.deq
      begin
        RailsMultisite::ConnectionManagement.establish_connection(db: db)
        job.call
      rescue => ex
        Discourse.handle_exception(ex, {message: "Running deferred code '#{desc}'"})
      end
    rescue => ex
      Discourse.handle_exception(ex, {message: "Processing deferred code queue"})
    ensure
      ActiveRecord::Base.connection_handler.clear_active_connections!
    end

  end

  class Defer
    extend Deferrable
    initialize
  end
end
