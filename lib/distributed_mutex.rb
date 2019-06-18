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
    @mutex.lock
    attempts = 0

    while !try_to_get_lock
      sleep 0.001
      # in readonly we will never be able to get a lock
      if @using_global_redis && Discourse.recently_readonly?
        attempts += 1

        if attempts > CHECK_READONLY_ATTEMPT
          raise Discourse::ReadOnly
        end
      end
    end

    yield

  ensure
    @redis.del @key
    @mutex.unlock
  end

  private

  def try_to_get_lock
    got_lock = false

    if @redis.setnx @key, Time.now.to_i + @validity
      @redis.expire @key, @validity
      got_lock = true
    else
      begin
        @redis.watch @key
        time = @redis.get @key

        if time && time.to_i < Time.now.to_i
          got_lock = @redis.multi do
            @redis.set @key, Time.now.to_i + @validity
          end
        end
      ensure
        @redis.unwatch
      end
    end

    got_lock
  end

end
