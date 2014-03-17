module Scheduler
  module Deferrable
    def initialize
      @async = Rails.env != "test"
      @queue = Queue.new
      @thread = Thread.new {
        while true
          do_work
        end
      }
    end

    # for test
    def async=(val)
      @async = val
    end

    def later(&blk)
      if @async
        @queue << [RailsMultisite::ConnectionManagement.current_db, blk]
      else
        blk.call
      end
    end

    def stop!
      @thread.kill
    end

    private

    def do_work
      db, job = @queue.deq
      RailsMultisite::ConnectionManagement.establish_connection(db: db)
      job.call
    rescue => ex
      Discourse.handle_exception(ex)
    ensure
      ActiveRecord::Base.connection_handler.clear_active_connections!
    end

  end

  class Defer
    extend Deferrable
    initialize
  end
end
