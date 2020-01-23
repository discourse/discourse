# frozen_string_literal: true

#
#  A wrapper around redis that namespaces keys with the current site id
#
require_dependency 'cache'
require_dependency 'concurrency'

class DiscourseRedis
  class RedisStatus
    MASTER_ROLE_STATUS = "role:master".freeze
    MASTER_LOADED_STATUS = "loading:0".freeze
    CONNECTION_TYPES = %w{normal pubsub}.each(&:freeze)

    def initialize(master_config, slave_config)
      master_config = master_config.dup.freeze unless master_config.frozen?
      slave_config = slave_config.dup.freeze unless slave_config.frozen?

      @master_config = master_config
      @slave_config = slave_config
    end

    def master_alive?
      master_client = connect(@master_config)

      begin
        info = master_client.call([:info])
      rescue Redis::ConnectionError, Redis::CannotConnectError, RuntimeError => ex
        raise ex if ex.class == RuntimeError && ex.message != "Name or service not known"
        warn "Master not alive, error connecting"
        return false
      ensure
        master_client.disconnect
      end

      unless info.include?(MASTER_LOADED_STATUS)
        warn "Master not alive, status is loading"
        return false
      end

      unless info.include?(MASTER_ROLE_STATUS)
        warn "Master not alive, role != master"
        return false
      end

      true
    end

    def fallback
      warn "Killing connections to slave..."

      slave_client = connect(@slave_config)

      begin
        CONNECTION_TYPES.each do |connection_type|
          slave_client.call([:client, [:kill, 'type', connection_type]])
        end
      rescue Redis::ConnectionError, Redis::CannotConnectError, RuntimeError => ex
        raise ex if ex.class == RuntimeError && ex.message != "Name or service not known"
        warn "Attempted a redis fallback, but connection to slave failed"
      ensure
        slave_client.disconnect
      end
    end

    private

    def connect(config)
      config = config.dup
      config.delete(:connector)
      ::Redis::Client.new(config)
    end

    def log_prefix
      @log_prefix ||= begin
        master_string = "#{@master_config[:host]}:#{@master_config[:port]}"
        slave_string = "#{@slave_config[:host]}:#{@slave_config[:port]}"
        "RedisStatus master=#{master_string} slave=#{slave_string}"
      end
    end

    def warn(message)
      Rails.logger.warn "#{log_prefix}: #{message}"
    end
  end

  class FallbackHandler
    def initialize(log_prefix, redis_status, execution)
      @log_prefix = log_prefix
      @redis_status = redis_status
      @mutex = execution.new_mutex
      @execution = execution
      @master = true
      @event_handlers = []
    end

    def add_callbacks(handler)
      @mutex.synchronize do
        @event_handlers << handler
      end
    end

    def start_reset
      @mutex.synchronize do
        if @master
          @master = false
          trigger(:down)
          true
        else
          false
        end
      end
    end

    def use_master?
      master = @mutex.synchronize { @master }
      if !master
        false
      elsif safe_master_alive?
        true
      else
        if start_reset
          @execution.spawn do
            loop do
              @execution.sleep 5
              info "Checking connection to master"
              if safe_master_alive?
                @mutex.synchronize do
                  @master = true
                  @redis_status.fallback
                  trigger(:up)
                end
                break
              end
            end
          end
        end

        false
      end
    end

    private

    attr_reader :log_prefix

    def trigger(event)
      @event_handlers.each do |handler|
        begin
          handler.public_send(event)
        rescue Exception => e
          Discourse.warn_exception(e, message: "Error running FallbackHandler callback")
        end
      end
    end

    def info(message)
      Rails.logger.info "#{log_prefix}: #{message}"
    end

    def safe_master_alive?
      begin
        @redis_status.master_alive?
      rescue Exception => e
        Discourse.warn_exception(e, message: "Error running master_alive?")
        false
      end
    end
  end

  class MessageBusFallbackCallbacks
    def down
      @keepalive_interval, MessageBus.keepalive_interval =
        MessageBus.keepalive_interval, 0
    end

    def up
      MessageBus.keepalive_interval = @keepalive_interval
    end
  end

  class MainRedisReadOnlyCallbacks
    def down
    end

    def up
      Discourse.clear_readonly!
      Discourse.request_refresh!
    end
  end

  class FallbackHandlers
    include Singleton

    def initialize
      @mutex = Mutex.new
      @fallback_handlers = {}
    end

    def handler_for(config)
      config = config.dup.freeze unless config.frozen?

      @mutex.synchronize do
        @fallback_handlers[[config[:host], config[:port]]] ||= begin
          log_prefix = "FallbackHandler #{config[:host]}:#{config[:port]}"
          slave_config = DiscourseRedis.slave_config(config)
          redis_status = RedisStatus.new(config, slave_config)

          handler =
            FallbackHandler.new(
              log_prefix,
              redis_status,
              Concurrency::ThreadedExecution.new
            )

          if config == GlobalSetting.redis_config
            handler.add_callbacks(MainRedisReadOnlyCallbacks.new)
          end

          if config == GlobalSetting.message_bus_redis_config
            handler.add_callbacks(MessageBusFallbackCallbacks.new)
          end

          handler
        end
      end
    end

    def self.handler_for(config)
      instance.handler_for(config)
    end
  end

  class Connector < Redis::Client::Connector
    def initialize(options)
      options = options.dup.freeze unless options.frozen?

      super(options)
      @slave_options = DiscourseRedis.slave_config(options).freeze
      @fallback_handler = DiscourseRedis::FallbackHandlers.handler_for(options)
    end

    def resolve
      if @fallback_handler.use_master?
        @options
      else
        @slave_options
      end
    end
  end

  def self.raw_connection(config = nil)
    config ||= self.config
    Redis.new(config)
  end

  def self.config
    GlobalSetting.redis_config
  end

  def self.slave_config(options = config)
    options.dup.merge!(host: options[:slave_host], port: options[:slave_port])
  end

  def initialize(config = nil, namespace: true)
    @config = config || DiscourseRedis.config
    @redis = DiscourseRedis.raw_connection(@config.dup)
    @namespace = namespace
  end

  def without_namespace
    # Only use this if you want to store and fetch data that's shared between sites
    @redis
  end

  def self.ignore_readonly
    yield
  rescue Redis::CommandError => ex
    if ex.message =~ /READONLY/
      unless Discourse.recently_readonly? || Rails.env.test?
        STDERR.puts "WARN: Redis is in a readonly state. Performed a noop"
      end

      Discourse.received_redis_readonly!
      nil
    else
      raise ex
    end
  end

  # prefix the key with the namespace
  def method_missing(meth, *args, &block)
    if @redis.respond_to?(meth)
      DiscourseRedis.ignore_readonly { @redis.public_send(meth, *args, &block) }
    else
      super
    end
  end

  # Proxy key methods through, but prefix the keys with the namespace
  [:append, :blpop, :brpop, :brpoplpush, :decr, :decrby, :exists, :expire, :expireat, :get, :getbit, :getrange, :getset,
   :hdel, :hexists, :hget, :hgetall, :hincrby, :hincrbyfloat, :hkeys, :hlen, :hmget, :hmset, :hset, :hsetnx, :hvals, :incr,
   :incrby, :incrbyfloat, :lindex, :linsert, :llen, :lpop, :lpush, :lpushx, :lrange, :lrem, :lset, :ltrim,
   :mapped_hmset, :mapped_hmget, :mapped_mget, :mapped_mset, :mapped_msetnx, :move, :mset,
   :msetnx, :persist, :pexpire, :pexpireat, :psetex, :pttl, :rename, :renamenx, :rpop, :rpoplpush, :rpush, :rpushx, :sadd, :scard,
   :sdiff, :set, :setbit, :setex, :setnx, :setrange, :sinter, :sismember, :smembers, :sort, :spop, :srandmember, :srem, :strlen,
   :sunion, :ttl, :type, :watch, :zadd, :zcard, :zcount, :zincrby, :zrange, :zrangebyscore, :zrank, :zrem, :zremrangebyrank,
   :zremrangebyscore, :zrevrange, :zrevrangebyscore, :zrevrank, :zrangebyscore ].each do |m|
    define_method m do |*args|
      args[0] = "#{namespace}:#{args[0]}" if @namespace
      DiscourseRedis.ignore_readonly { @redis.public_send(m, *args) }
    end
  end

  def mget(*args)
    args.map! { |a| "#{namespace}:#{a}" }  if @namespace
    DiscourseRedis.ignore_readonly { @redis.mget(*args) }
  end

  def del(k)
    DiscourseRedis.ignore_readonly do
      k = "#{namespace}:#{k}"  if @namespace
      @redis.del k
    end
  end

  def scan_each(options = {}, &block)
    DiscourseRedis.ignore_readonly do
      match = options[:match].presence || '*'

      options[:match] =
        if @namespace
          "#{namespace}:#{match}"
        else
          match
        end

      if block
        @redis.scan_each(options) do |key|
          key = remove_namespace(key) if @namespace
          block.call(key)
        end
      else
        @redis.scan_each(options).map do |key|
          key = remove_namespace(key) if @namespace
          key
        end
      end
    end
  end

  def keys(pattern = nil)
    DiscourseRedis.ignore_readonly do
      pattern = pattern || '*'
      pattern = "#{namespace}:#{pattern}" if @namespace
      keys = @redis.keys(pattern)

      if @namespace
        len = namespace.length + 1
        keys.map! { |k| k[len..-1] }
      end

      keys
    end
  end

  def delete_prefixed(prefix)
    DiscourseRedis.ignore_readonly do
      keys("#{prefix}*").each { |k| Discourse.redis.del(k) }
    end
  end

  def flushdb
    DiscourseRedis.ignore_readonly do
      keys.each { |k| del(k) }
    end
  end

  def reconnect
    @redis._client.reconnect
  end

  def namespace_key(key)
    if @namespace
      "#{namespace}:#{key}"
    else
      key
    end
  end

  def namespace
    RailsMultisite::ConnectionManagement.current_db
  end

  def self.namespace
    Rails.logger.warn("DiscourseRedis.namespace is going to be deprecated, do not use it!")
    RailsMultisite::ConnectionManagement.current_db
  end

  def self.new_redis_store
    Cache.new
  end

  private

  def remove_namespace(key)
    key[(namespace.length + 1)..-1]
  end
end
