# frozen_string_literal: true

# Cross-process locking using Redis.
# Expiration happens when the current time is greater than the expire time
class DistributedMutex
  DEFAULT_VALIDITY = 60
  CHECK_READONLY_ATTEMPTS = 5

  LOCK_SCRIPT = DiscourseRedis::EvalHelper.new <<~LUA
    local now = redis.call("time")[1]
    local expire_time = now + ARGV[1]
    local current_expire_time = redis.call("get", KEYS[1])

    if current_expire_time and tonumber(now) <= tonumber(current_expire_time) then
      return nil
    else
      local result = redis.call("setex", KEYS[1], ARGV[1] + 1, tostring(expire_time))
      return expire_time
    end
  LUA

  UNLOCK_SCRIPT = DiscourseRedis::EvalHelper.new <<~LUA
    local current_expire_time = redis.call("get", KEYS[1])

    if current_expire_time == ARGV[1] then
      local result = redis.call("del", KEYS[1])
      return result ~= nil
    else
      return false
    end
  LUA

  def self.synchronize(
    key,
    redis: nil,
    validity: DEFAULT_VALIDITY,
    max_get_lock_attempts: nil,
    &blk
  )
    self.new(
      key,
      redis: redis,
      validity: validity,
      max_get_lock_attempts: max_get_lock_attempts,
    ).synchronize(&blk)
  end

  def initialize(key, redis: nil, validity: DEFAULT_VALIDITY, max_get_lock_attempts: nil)
    @key = key
    @using_global_redis = true if !redis
    @redis = redis || Discourse.redis
    @mutex = Mutex.new
    @validity = validity
    @max_get_lock_attempts = max_get_lock_attempts
  end

  # NOTE wrapped in mutex to maintain its semantics
  def synchronize
    result = nil

    @mutex.synchronize do
      expire_time = get_lock

      begin
        result = yield
      ensure
        current_time = redis.time[0]
        if current_time > expire_time
          warn(
            "held for too long, expected max: #{@validity} secs, took an extra #{current_time - expire_time} secs",
          )
        end

        unlocked = UNLOCK_SCRIPT.eval(redis, [prefixed_key], [expire_time.to_s])
        if !unlocked && current_time <= expire_time
          warn("the redis key appears to have been tampered with before expiration")
        end
      end
    end

    result
  end

  class MaximumAttemptsExceeded < StandardError
  end

  private

  attr_reader :key
  attr_reader :redis
  attr_reader :validity
  attr_reader :max_get_lock_attempts

  def get_lock
    attempts = 0

    while true
      expire_time = LOCK_SCRIPT.eval(redis, [prefixed_key], [validity])

      return expire_time if expire_time

      # Exponential backoff, max duration 1s
      interval = attempts < 10 ? (0.001 * 2**attempts) : 1
      sleep interval
      attempts += 1

      # in readonly we will never be able to get a lock
      if @using_global_redis && Discourse.recently_readonly? && attempts > CHECK_READONLY_ATTEMPTS
        raise Discourse::ReadOnly
      end

      if max_get_lock_attempts && attempts > max_get_lock_attempts
        raise DistributedMutex::MaximumAttemptsExceeded
      end
    end
  end

  def prefixed_key
    @prefixed_key ||= redis.respond_to?(:namespace_key) ? redis.namespace_key(key) : key
  end

  def warn(msg)
    Rails.logger.warn("DistributedMutex(#{key.inspect}): #{msg}")
  end
end
