#
#  A wrapper around redis that namespaces keys with the current site id
#
require_dependency 'cache'

class DiscourseRedis
  class FallbackHandler
    include Singleton

    MASTER_LINK_STATUS = "master_link_status:up".freeze
    CONNECTION_TYPES = %w{normal pubsub}.each(&:freeze)

    def initialize
      @master = true
      @running = false
      @mutex = Mutex.new
      @slave_config = DiscourseRedis.slave_config
      @message_bus_keepalive_interval = MessageBus.keepalive_interval
    end

    def verify_master
      synchronize { return if @thread && @thread.alive? }

      @thread = Thread.new do
        loop do
          begin
            thread = Thread.new { initiate_fallback_to_master }
            thread.join
            break if synchronize { @master }
            sleep 5
          ensure
            thread.kill
          end
        end
      end
    end

    def initiate_fallback_to_master
      success = false

      begin
        slave_client = ::Redis::Client.new(@slave_config)
        logger.warn "#{log_prefix}: Checking connection to master server..."

        if slave_client.call([:info]).split("\r\n").include?(MASTER_LINK_STATUS)
          logger.warn "#{log_prefix}: Master server is active, killing all connections to slave..."

          self.master = true

          CONNECTION_TYPES.each do |connection_type|
            slave_client.call([:client, [:kill, 'type', connection_type]])
          end

          MessageBus.keepalive_interval = @message_bus_keepalive_interval
          Discourse.clear_readonly!
          Discourse.request_refresh!
          success = true
        end
      ensure
        slave_client.disconnect
      end

      success
    end

    def master
      synchronize { @master }
    end

    def master=(args)
      synchronize do
        @master = args

        # Disables MessageBus keepalive when Redis is in readonly mode
        MessageBus.keepalive_interval = 0 if !@master
      end
    end

    private

    def synchronize
      @mutex.synchronize { yield }
    end

    def logger
      Rails.logger
    end

    def log_prefix
      "#{self.class}"
    end
  end

  class Connector < Redis::Client::Connector
    def initialize(options)
      super(options)
      @slave_options = DiscourseRedis.slave_config(options)
      @fallback_handler = DiscourseRedis::FallbackHandler.instance
    end

    def resolve(client = nil)
      if !@fallback_handler.master
        @fallback_handler.verify_master
        return @slave_options
      end

      begin
        options = @options.dup
        options.delete(:connector)
        client ||= Redis::Client.new(options)
        loading = client.call([:info]).split("\r\n").include?("loading:1")
        loading ? @slave_options : @options
      rescue Redis::ConnectionError, Redis::CannotConnectError, RuntimeError => ex
        raise ex if ex.class == RuntimeError && ex.message != "Name or service not known"
        @fallback_handler.master = false
        @fallback_handler.verify_master
        raise ex
      ensure
        client.disconnect
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
    @redis = DiscourseRedis.raw_connection(@config)
    @namespace = namespace
  end

  def self.fallback_handler
    @fallback_handler ||= DiscourseRedis::FallbackHandler.instance
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

      fallback_handler.verify_master if !fallback_handler.master
      Discourse.received_readonly!
      nil
    else
      raise ex
    end
  end

  # prefix the key with the namespace
  def method_missing(meth, *args, &block)
    if @redis.respond_to?(meth)
      DiscourseRedis.ignore_readonly { @redis.send(meth, *args, &block) }
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
      DiscourseRedis.ignore_readonly { @redis.send(m, *args) }
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
      keys("#{prefix}*").each { |k| $redis.del(k) }
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
