# frozen_string_literal: true

module CachedCounting
  extend ActiveSupport::Concern

  LUA_GET_DEL = DiscourseRedis::EvalHelper.new <<~LUA
    local result = redis.call("GET", KEYS[1])
    redis.call("DEL", KEYS[1])

    return result
  LUA

  QUEUE = Queue.new
  SLEEP_SECONDS = 1
  FLUSH_DB_ITERATIONS = 60
  MUTEX = Mutex.new

  def self.disable
    @enabled = false
    if @thread && @thread.alive?
      @thread.wakeup
      @thread.join
    end
  end

  def self.enabled?
    @enabled != false
  end

  def self.enable
    @enabled = true
  end

  def self.reset
    clear_queue!
    clear_flush_to_db_lock!
  end

  def self.ensure_thread!
    return if !enabled?

    MUTEX.synchronize do
      if !@thread&.alive?
        @thread = nil
      end
      @thread ||= Thread.new { thread_loop }
    end
  end

  def self.thread_loop
    iterations = 0
    while true
      break if !enabled?

      sleep SLEEP_SECONDS
      flush_in_memory
      if (iterations >= FLUSH_DB_ITERATIONS) || @flush
        iterations = 0
        flush_to_db
        @flush = false
      end
      iterations += 1
    end
  end

  def self.flush
    @flush = true
    @thread.wakeup
    while @flush
      sleep 0.001
    end
  end

  COUNTER_PREFIX = "__DCC__"

  def self.flush_in_memory
    counts = nil
    while QUEUE.length > 0
      # only 1 consumer, no need to avoid blocking
      key, klass, db, time = QUEUE.deq
      _redis_key = "#{COUNTER_PREFIX},#{klass},#{db},#{time.strftime("%Y%m%d")},#{key}"
      counts ||= Hash.new(0)
      counts[_redis_key] += 1
    end

    if counts
      counts.each do |redis_key, count|
        # TODO this whole loop can be done in a single LUA script
        # concerns:
        # - Is there a limit of params, will we need to chunk it
        # - Would this lock up redis for too long, chunk it due to that?
        Discourse.redis.without_namespace.incrby(redis_key, count)
      end
    end
  end

  DB_FLUSH_COOLDOWN_SECONDS = 60
  DB_COOLDOWN_KEY = "cached_counting_cooldown"

  def self.flush_to_db
    redis = Discourse.redis.without_namespace
    DistributedMutex.synchronize("flush_counters_to_db", redis: redis, validity: 5.minutes) do
      if allowed_to_flush_to_db?
        # TODO can be done in a single eval (including keys call)
        # same concern as above
        redis.keys("#{COUNTER_PREFIX}*").each do |key|

          val = LUA_GET_DEL.eval(
            redis,
            [key]
          ).to_i

          _prefix, klass_name, db, date, local_key = key.split(",", 5)
          date = Date.strptime(date, "%Y%m%d")
          klass = Module.const_get(klass_name)

          RailsMultisite::ConnectionManagement.with_connection(db) do
            klass.write_cache!(local_key, val, date)
          end
        end
      end
    end
  end

  def self.clear_flush_to_db_lock!
    Discourse.redis.without_namespace.del(DB_COOLDOWN_KEY)
  end

  def self.flush_to_db_lock_ttl
    Discourse.redis.without_namespace.ttl(DB_COOLDOWN_KEY)
  end

  def self.allowed_to_flush_to_db?
    Discourse.redis.without_namespace.set(DB_COOLDOWN_KEY, "1", ex: DB_FLUSH_COOLDOWN_SECONDS, nx: true)
  end

  def self.queue(key, klass)
    QUEUE.push([key, klass, RailsMultisite::ConnectionManagement.current_db, Time.now.utc])
  end

  def self.clear_queue!
    QUEUE.clear
    redis = Discourse.redis.without_namespace
    redis.keys("#{COUNTER_PREFIX}*").each do |key|
      redis.del(key)
    end
  end

  class_methods do
    def perform_increment!(key)
      CachedCounting.ensure_thread!
      CachedCounting.queue(key, self)
    end

    def write_cache!(key, count, date)
      raise NotImplementedError
    end

  end
end
