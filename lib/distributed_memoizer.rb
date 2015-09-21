class DistributedMemoizer

  # never wait for longer that 1 second for a cross process lock
  MAX_WAIT = 2
  LOCK = Mutex.new

  # memoize a key across processes and machines
  def self.memoize(key, duration = 60 * 60 * 24, redis = nil)
    redis ||= $redis

    redis_key = self.redis_key(key)

    unless result = redis.get(redis_key)
      redis_lock_key = self.redis_lock_key(key)

      start = Time.new
      got_lock = false

      begin
        while Time.new < start + MAX_WAIT && !got_lock
          LOCK.synchronize do
            got_lock = get_lock(redis,redis_lock_key)
          end
          sleep 0.001
        end

        unless result = redis.get(redis_key)
          result = yield
          redis.setex(redis_key, duration, result)
        end

      ensure
        # NOTE: delete regardless so next one in does not need to wait MAX_WAIT again
        redis.del(redis_lock_key)
      end
    end

    result
  end


  def self.redis_lock_key(key)
    "memoize_lock_" << key
  end

  def self.redis_key(key)
    "memoize_" << key
  end

  protected

  def self.get_lock(redis, redis_lock_key)
    redis.watch(redis_lock_key)
    current = redis.get(redis_lock_key)
    return false if current

    unique = SecureRandom.hex

    result = redis.multi do
      redis.setex(redis_lock_key, MAX_WAIT, unique)
    end

    redis.unwatch
    result == ["OK"]
  end
end
