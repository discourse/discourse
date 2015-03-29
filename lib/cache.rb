# Discourse specific cache, enforces 1 day expiry

class Cache < ActiveSupport::Cache::Store

  # nothing is cached for longer than 1 day EVER
  # there is no reason to have data older than this clogging redis
  # it is dangerous cause if we rename keys we will be stuck with
  # pointless data
  MAX_CACHE_AGE = 1.day unless defined? MAX_CACHE_AGE

  def initialize(opts = {})
    @namespace = opts[:namespace] || "_CACHE_"
    super(opts)
  end

  def redis
    $redis
  end

  def reconnect
    redis.reconnect
  end

  def clear
    redis.keys("#{@namespace}:*").each do |k|
      redis.del(k)
    end
  end

  def namespaced_key(key, opts=nil)
    "#{@namespace}:" << key
  end

  protected

  def read_entry(key, options)
    if data = redis.get(key)
      data = Marshal.load(data)
      ActiveSupport::Cache::Entry.new data
    end
  rescue
    # corrupt cache, fail silently for now, remove rescue later
  end

  def write_entry(key, entry, options)
    dumped = Marshal.dump(entry.value)
    expiry = options[:expires_in] || MAX_CACHE_AGE
    redis.setex(key, expiry, dumped)
    true
  end

  def delete_entry(key, options)
    redis.del key
  end

end
