# Standard Rails.cache is lacking support for this interface, possibly yank all in from redis:cache and start using this instead
#

class Cache
  def initialize(redis=nil)
    @redis = redis
  end

  def redis
    @redis || $redis
  end

  def fetch(key, options={})
    result = redis.get key
    if result.nil?
      if expiry = options[:expires_in]
        if block_given?
          result = yield
          redis.setex(key, expiry, result)
        end
      else
        if block_given?
          result = yield
          redis.set(key, result)
        end
      end
    end

    if family = family_key(options[:family])
      redis.sadd(family, key)
    end

    result
  end

  def delete(key)
    redis.del(key)
  end

  def delete_by_family(key)
    k = family_key(key)
    redis.smembers(k).each do |member|
      delete(member)
    end
    redis.del(k)
  end

  private

  def family_key(name)
    if name
      "FAMILY_#{name}"
    end
  end
end
