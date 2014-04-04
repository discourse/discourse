# THIS FILE IS TO BE EXTRACTED FROM DISCOURSE IT IS LICENSED UNDER THE MIT LICENSE
#
# The MIT License (MIT)
#
# Copyright (c) 2013 Discourse
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Hook into unicorn, unicorn middleware, not rack middleware
#
# Since we need no knowledge about the request we can simply
#  hook unicorn
module Middleware::UnicornOobgc

  MIN_REQUESTS_PER_OOBGC = 3

  # TUNE ME, for Discourse this number is good
  MIN_FREE_SLOTS = 50_000

  # The oobgc implementation is far more efficient in 2.1
  # as we have a bunch of profiling hooks to hook it
  # use @tmm1s implementation
  def use_gctools?
    if @use_gctools.nil?
      @use_gctools =
        if RUBY_VERSION >= "2.1.0"
          require "gctools/oobgc"
          true
        else
          false
        end
    end
    @use_gctools
  end

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

    if use_gctools?
      super(client)
      GC::OOB.run
      return
    end

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
        new_delta = (@max_delta * 1.5).to_i
        @max_delta = [new_delta, delta].min
      else
        # this may seem like a very tiny decay rate, but some apps using caching
        # can really mess stuff up, if our delta is too low the algorithm fails
        new_delta = (@max_delta * 0.99).to_i
        @max_delta = [new_delta, delta].max
      end

      if @max_delta < MIN_FREE_SLOTS
        @max_delta = MIN_FREE_SLOTS
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
