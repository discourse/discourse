# frozen_string_literal: true

class DistributedMemoizer
  # never wait for longer that 1 second for a cross process lock
  MAX_WAIT = 1

  # memoize a key across processes and machines
  def self.memoize(key, duration = 60 * 60 * 24, redis = Discourse.redis)
    redis_lock_key = self.redis_lock_key(key)
    redis_key = self.redis_key(key)

    DistributedMutex.synchronize(redis_lock_key, redis: redis, validity: MAX_WAIT) do
      result = redis.get(redis_key)

      unless result
        result = yield
        redis.setex(redis_key, duration, result)
      end

      result
    end
  end

  def self.redis_lock_key(key)
    "memoize_lock_#{key}"
  end

  def self.redis_key(key)
    "memoize_#{key}"
  end
end
