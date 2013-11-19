
# Hook into unicorn, unicorn middleware, not rack middleware
#
# Since we need no knowledge about the request we can simply
#  hook unicorn
module Middleware::UnicornOobgc

  MIN_REQUESTS_PER_OOBGC = 3

  def verbose(msg=nil)
    @verbose ||= ENV["OOBGC_VERBOSE"] == "1" ? :true : :false
    if @verbose == :true
      if(msg)
        puts msg
      end

      true
    end
  end

  def self.init
    # hook up HttpServer intercept
    ObjectSpace.each_object(Unicorn::HttpServer) do |s|
      s.extend(self)
    end
  rescue
    puts "Attempted to patch Unicorn but it is not loaded"
  end

  # the closer this is to the GC run the more accurate it is
  def estimate_live_num_at_gc(stat)
    stat[:heap_live_num] + stat[:heap_free_num]
  end

  def process_client(client)
    stat = GC.stat

    @num_requests ||= 0
    @num_requests += 1

    gc_count = stat[:count]
    live_num = stat[:heap_live_num]

    @expect_gc_at ||= estimate_live_num_at_gc(stat)

    super(client) # Unicorn::HttpServer#process_client

    # at this point client is serviced
    stat = GC.stat
    new_gc_count = stat[:count]
    new_live_num = stat[:heap_live_num]

    # no GC happened during the request
    if new_gc_count == gc_count
      delta = new_live_num - live_num

      @max_delta ||= delta

      if delta > @max_delta
        new_delta = (delta * 1.5).to_i
        @max_delta = [new_delta, delta].min
      else
        # this may seem like a very tiny decay rate, but some apps using caching
        # can really mess stuff up, if our delta is too low the algorithm fails
        new_delta = (delta * 0.995).to_i
        @max_delta = [new_delta, delta].max
      end

      if @num_requests > MIN_REQUESTS_PER_OOBGC && @max_delta * 2 + new_live_num > @expect_gc_at
        t = Time.now
        GC.start
        stat = GC.stat
        @expect_gc_at = estimate_live_num_at_gc(stat)
        verbose "OobGC hit pid: #{Process.pid} req: #{@num_requests} max delta: #{@max_delta} expect at: #{@expect_gc_at} #{((Time.now - t) * 1000).to_i}ms saved"
        @num_requests = 0
      end
    else

      verbose "OobGC miss pid: #{Process.pid} reqs: #{@num_requests} max delta: #{@max_delta}"

      @num_requests = 0
      @expect_gc_at = estimate_live_num_at_gc(stat)

    end

  end

end
