# frozen_string_literal: true

# Cross-process locking using Redis.
class DistributedMutex
  DEFAULT_VALIDITY ||= 60

  def self.synchronize(key, redis: nil, validity: DEFAULT_VALIDITY, &blk)
    self.new(
      key,
      redis: redis,
      validity: validity
    ).synchronize(&blk)
  end

  def initialize(key, redis: nil, validity: DEFAULT_VALIDITY)
    @key = key
    @using_global_redis = true if !redis
    @redis = redis || $redis
    @mutex = Mutex.new
    @validity = validity
  end

  CHECK_READONLY_ATTEMPT ||= 10

  # NOTE wrapped in mutex to maintain its semantics
  def synchronize
    @mutex.synchronize do
      expire_time = get_lock

      begin
        yield
      ensure
        current_time = redis.time[0]
        if current_time > expire_time
          warn("held for too long, expected max: #{@validity} secs, took an extra #{current_time - expire_time} secs")
        end

        if !unlock(expire_time) && current_time <= expire_time
          warn("didn't unlock cleanly")
        end
      end
    end
  end

  private

  attr_reader :key
  attr_reader :redis
  attr_reader :validity

  def warn(msg)
    Rails.logger.warn("DistributedMutex(#{key.inspect}): #{msg}")
  end

  def get_lock
    attempts = 0

    while true
      got_lock, expire_time = try_to_get_lock
      if got_lock
        return expire_time
      end

      sleep 0.001
      # in readonly we will never be able to get a lock
      if @using_global_redis && Discourse.recently_readonly?
        attempts += 1

        if attempts > CHECK_READONLY_ATTEMPT
          raise Discourse::ReadOnly
        end
      end
    end
  end

  def try_to_get_lock
    got_lock = false

    now = redis.time[0]
    expire_time = now + validity

    redis.watch key

    current_expire_time = redis.get key

    if current_expire_time && current_expire_time.to_i > now
      redis.unwatch

      got_lock = false
    else
      result =
        redis.multi do
          redis.set key, expire_time.to_s
          redis.expire key, validity
        end

      got_lock = !result.nil?
    end

    [got_lock, expire_time]
  end

  def unlock(expire_time)
    redis.watch key
    current_expire_time = redis.get key

    if current_expire_time == expire_time.to_s
      result =
        redis.multi do
          redis.del key
        end
      return !result.nil?
    else
      redis.unwatch
      return false
    end
  end
end
