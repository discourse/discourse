# Cross-process locking using Redis.
class DistributedMutex
  attr_accessor :redis
  attr_reader :got_lock

  def initialize(key, redis=nil)
    @key = key
    @redis = redis || $redis
    @got_lock = false
  end

  def try_to_get_lock
    if redis.setnx @key, Time.now.to_i + 60
      redis.expire @key, 60
      @got_lock = true
    else
      begin
        redis.watch @key
        time = redis.get @key
        if time && time.to_i < Time.now.to_i
          @got_lock = redis.multi do
            redis.set @key, Time.now.to_i + 60
          end
        end
      ensure
        redis.unwatch
      end
    end
  end

  def get_lock
    return if @got_lock

    start = Time.now
    while !@got_lock
      try_to_get_lock
    end
  end

  def release_lock
    redis.del @key
    @got_lock = false
  end

  def synchronize
    get_lock
    yield
  ensure
    release_lock
  end
end
