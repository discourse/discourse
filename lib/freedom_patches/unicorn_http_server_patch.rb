# frozen_string_literal: true

if ENV["DISCOURSE_DUMP_BACKTRACES_ON_UNICORN_WORKER_TIMEOUT"] && defined?(Unicorn::HttpServer)
  module UnicornHTTPServerPatch
    # Original source: https://github.com/defunkt/unicorn/blob/6c9c442fb6aa12fd871237bc2bb5aec56c5b3538/lib/unicorn/http_server.rb#L477-L496
    def murder_lazy_workers
      next_sleep = @timeout - 1
      now = time_now.to_i
      @workers.dup.each_pair do |wpid, worker|
        tick = worker.tick
        0 == tick and next # skip workers that haven't processed any clients
        diff = now - tick
        tmp = @timeout - diff

        # START MONKEY PATCH
        if tmp < 2
          logger.error "worker=#{worker.nr} PID:#{wpid} running too long " \
                         "(#{diff}s), sending USR2 to dump thread backtraces"
          kill_worker(:USR2, wpid)
        end
        # END MONKEY PATCH

        if tmp >= 0
          next_sleep > tmp and next_sleep = tmp
          next
        end
        next_sleep = 0
        logger.error "worker=#{worker.nr} PID:#{wpid} timeout " \
                       "(#{diff}s > #{@timeout}s), killing"

        kill_worker(:KILL, wpid) # take no prisoners for timeout violations
      end
      next_sleep <= 0 ? 1 : next_sleep
    end
  end

  Unicorn::HttpServer.prepend(UnicornHTTPServerPatch)
end
