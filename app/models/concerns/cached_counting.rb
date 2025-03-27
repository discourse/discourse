# frozen_string_literal: true

module CachedCounting
  extend ActiveSupport::Concern

  LUA_HGET_DEL = DiscourseRedis::EvalHelper.new <<~LUA
    local result = redis.call("HGET", KEYS[1], KEYS[2])
    redis.call("HDEL", KEYS[1], KEYS[2])

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
    @last_ensure_thread = nil
    clear_queue!
    clear_flush_to_db_lock!
  end

  ENSURE_THREAD_COOLDOWN_SECONDS = 5

  def self.ensure_thread!
    return if !enabled?

    MUTEX.synchronize do
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      delta = @last_ensure_thread && (now - @last_ensure_thread)

      if delta && delta < ENSURE_THREAD_COOLDOWN_SECONDS
        # creating threads can be very expensive and bog down a process
        return
      end

      @last_ensure_thread = now

      @thread = nil if !@thread&.alive?
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
  rescue => ex
    if Redis::ReadOnlyError === ex
      # do not warn for Redis readonly mode
    elsif PG::ReadOnlySqlTransaction === ex
      # do not warn for PG readonly mode
    else
      Discourse.warn_exception(ex, message: "Unexpected error while processing cached counts")
    end
  end

  def self.flush
    if @thread && @thread.alive?
      @flush = true
      @thread.wakeup
      sleep 0.001 while @flush
    else
      flush_in_memory
      flush_to_db
    end
  end

  COUNTER_REDIS_HASH = "CounterCacheHash"

  def self.flush_in_memory
    counts = nil
    while QUEUE.length > 0
      # only 1 consumer, no need to avoid blocking
      key, klass, db, time = QUEUE.deq
      _redis_key = "#{klass},#{db},#{time.strftime("%Y%m%d")},#{key}"
      counts ||= Hash.new(0)
      counts[_redis_key] += 1
    end

    if counts
      counts.each do |redis_key, count|
        Discourse.redis.without_namespace.hincrby(COUNTER_REDIS_HASH, redis_key, count)
      end
    end
  end

  DB_FLUSH_COOLDOWN_SECONDS = 60
  DB_COOLDOWN_KEY = "cached_counting_cooldown"

  def self.flush_to_db
    redis = Discourse.redis.without_namespace
    DistributedMutex.synchronize("flush_counters_to_db", redis: redis, validity: 5.minutes) do
      if allowed_to_flush_to_db?
        redis
          .hkeys(COUNTER_REDIS_HASH)
          .each do |key|
            val = LUA_HGET_DEL.eval(redis, [COUNTER_REDIS_HASH, key]).to_i

            # unlikely (protected by mutex), but protect just in case
            # could be a race condition in test
            if val > 0
              klass_name, db, date, local_key = key.split(",", 4)
              date = Date.strptime(date, "%Y%m%d")
              klass = Module.const_get(klass_name)

              RailsMultisite::ConnectionManagement.with_connection(db) do
                klass.write_cache!(local_key, val, date)
              end
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
    Discourse.redis.without_namespace.set(
      DB_COOLDOWN_KEY,
      "1",
      ex: DB_FLUSH_COOLDOWN_SECONDS,
      nx: true,
    )
  end

  def self.queue(key, klass)
    QUEUE.push([key, klass, RailsMultisite::ConnectionManagement.current_db, Time.now.utc])
  end

  def self.clear_queue!
    QUEUE.clear
    redis = Discourse.redis.without_namespace
    redis.del(COUNTER_REDIS_HASH)
  end

  class_methods do
    if Rails.env.test?
      # perform increment is a risky call in test,
      # it shifts stuff to background threads and leaks
      # data in the DB
      # Require caller is deliberate if they want that
      #
      # Splitting implementation to avoid any perf impact
      # given this is a method that is called a lot
      def perform_increment!(key, async: false)
        if async
          CachedCounting.ensure_thread!
          CachedCounting.queue(key, self)
        else
          CachedCounting.queue(key, self)
          CachedCounting.clear_flush_to_db_lock!
          CachedCounting.flush_in_memory
          CachedCounting.flush_to_db
        end
      end
    else
      def perform_increment!(key)
        CachedCounting.ensure_thread!
        CachedCounting.queue(key, self)
      end
    end

    def write_cache!(key, count, date)
      raise NotImplementedError
    end
  end
end
