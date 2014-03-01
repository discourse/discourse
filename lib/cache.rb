# Discourse specific cache supports expire by family missing from standard cache

class Cache < ActiveSupport::Cache::Store

  def initialize(opts = {})
    opts[:namespace] ||= "_CACHE_"
    super(opts)
  end

  def redis
    $redis
  end

  def delete_by_family(key)
    k = family_key(key, options)
    redis.smembers(k).each do |member|
      redis.del(member)
    end
    redis.del(k)
  end

  def reconnect
    redis.reconnect
  end

  def clear
    redis.keys.each do |k|
      redis.del(k) if k =~ /^_CACHE_:/
    end
  end

  def namespaced_key(key, opts=nil)
    opts ||= options
    super(key,opts)
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

    if expiry = options[:expires_in]
      redis.setex(key, expiry, dumped)
    else
      redis.set(key, dumped)
    end

    if family = family_key(options[:family], options)
      redis.sadd(family, key)
    end

    true
  end

  def delete_entry(key, options)
    redis.del key
  end

  private

  def family_key(name, options)
    if name
      key = namespaced_key(name, options)
      key << "FAMILY:#{name}"
    end
  end

end
