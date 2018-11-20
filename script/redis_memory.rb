require File.expand_path("../../config/environment", __FILE__)

@redis = $redis.without_namespace

stats = {}

@redis.scan_each do |k|
  type = @redis.type k
  debug = @redis.debug :object, k
  len = debug.split("serializedlength:")[1].to_i

  case type
  when "zset"
    elems = @redis.zcard k
  when "list"
    elems = @redis.llen k
  when "hash"
    elems = @redis.hlen k
  end

  stats[k] = [len, type, elems]
end

puts "Top 100 keys"
stats.sort { |a, b| b[1][0] <=> a[1][0] }.first(50).each do |k, (len, type, elems)|
  elems = " [#{elems}]" if elems
  puts "#{k} #{type} #{len}#{elems}"
end
