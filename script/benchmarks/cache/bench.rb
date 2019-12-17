# frozen_string_literal: true

require 'benchmark/ips'
require File.expand_path('../../../../config/environment', __FILE__)

Benchmark.ips do |x|

  x.report("redis setex string") do |times|
    while times > 0
      Discourse.redis.setex("test_key", 60, "test")
      times -= 1
    end
  end

  x.report("redis setex marshal string") do |times|
    while times > 0
      Discourse.redis.setex("test_keym", 60, Marshal.dump("test"))
      times -= 1
    end
  end

  x.report("Discourse cache string") do |times|
    while times > 0
      Discourse.cache.write("test_key", "test", expires_in: 60)
      times -= 1
    end
  end

  x.report("Rails cache string") do |times|
    while times > 0
      Rails.cache.write("test_key_rails", "test", expires_in: 60)
      times -= 1
    end
  end

  x.compare!
end

Benchmark.ips do |x|
  x.report("redis get string") do |times|
    while times > 0
      Discourse.redis.get("test_key")
      times -= 1
    end
  end

  x.report("redis get string marshal") do |times|
    while times > 0
      Marshal.load(Discourse.redis.get("test_keym"))
      times -= 1
    end
  end

  x.report("Discourse read cache string") do |times|
    while times > 0
      Discourse.cache.read("test_key")
      times -= 1
    end
  end

  x.report("Rails read cache string") do |times|
    while times > 0
      Rails.cache.read("test_key_rails")
      times -= 1
    end
  end

  x.compare!
end

# Comparison:
#   redis setex string:    13250.0 i/s
# redis setex marshal string:    12866.4 i/s - same-ish: difference falls within error
# Discourse cache string:    10443.0 i/s - 1.27x  slower
#   Rails cache string:    10367.9 i/s - 1.28x  slower

# Comparison:
#     redis get string:    13147.4 i/s
# redis get string marshal:    12789.2 i/s - same-ish: difference falls within error
# Rails read cache string:    10486.4 i/s - 1.25x  slower
# Discourse read cache string:    10457.1 i/s - 1.26x  slower
#
# After Cache re-write
#
# Comparison:
#   redis setex string:    13390.9 i/s
# redis setex marshal string:    13202.0 i/s - same-ish: difference falls within error
# Discourse cache string:    12406.5 i/s - same-ish: difference falls within error
#   Rails cache string:    12289.2 i/s - same-ish: difference falls within error
#
# Comparison:
#     redis get string:    13589.6 i/s
# redis get string marshal:    13118.3 i/s - same-ish: difference falls within error
# Rails read cache string:    12482.2 i/s - same-ish: difference falls within error
# Discourse read cache string:    12296.8 i/s - same-ish: difference falls within error
