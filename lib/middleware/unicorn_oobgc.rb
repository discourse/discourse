
# Hook into unicorn, unicorn middleware, not rack middleware
#
# Since we need no knowledge about the request we can simply
#  hook unicorn
module Middleware::UnicornOobgc

  MIN_REQUESTS_PER_OOBGC = 5
  MAX_DELTAS = 25

  def self.init
    # hook up HttpServer intercept
    ObjectSpace.each_object(Unicorn::HttpServer) do |s|
      s.extend(self)
    end
  rescue
    puts "Attempted to patch Unicorn but it is not loaded"
  end

  def process_client(client)
    stat = GC.stat

    @previous_deltas ||= []
    @num_requests ||= 0
    @num_requests += 1

    # only track N deltas
    if @previous_deltas.length > MAX_DELTAS
      @previous_deltas.delete_at(0)
    end

    gc_count = stat[:count]
    live_num = stat[:heap_live_num]

    super(client) # Unicorn::HttpServer#process_client

    # at this point client is serviced
    stat = GC.stat
    new_gc_count = stat[:count]
    new_live_num = stat[:heap_live_num]

    # no GC happened during the request
    if new_gc_count == gc_count
      @previous_deltas << (new_live_num - live_num)

      if @gc_live_num && @num_requests > MIN_REQUESTS_PER_OOBGC
        largest = @previous_deltas.max
        if (largest * 3) + new_live_num > @gc_live_num
          # While tuning consider printing this out, each time this happens you saved
          # a user from running a GC inline

          # t = Time.now
          GC.start
          # puts "OobGC invoked req count: #{@num_requests} largest delta: #{largest} #{((Time.now - t) * 1000).to_i}ms saved"
          @num_requests = 0
        end
      end
    else
      puts "OobGC: GC live num adjusted: old live_num #{@gc_live_num}  new: #{live_num} - reqs since GC: #{@num_requests} largest delta: #{@previous_deltas.max}"

      @num_requests = 0
      @gc_live_num = live_num

    end

  end

end
