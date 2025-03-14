# frozen_string_literal: true

#
#  A wrapper around redis that namespaces keys with the current site id
#

class DiscourseRedis
  def self.raw_connection(config = nil)
    config ||= self.config
    Redis.new(config)
  end

  def self.config
    GlobalSetting.redis_config
  end

  def initialize(config = nil, namespace: true, raw_redis: nil)
    @config = config || DiscourseRedis.config
    @redis = raw_redis || DiscourseRedis.raw_connection(@config.dup)
    @namespace = namespace
  end

  def without_namespace
    # Only use this if you want to store and fetch data that's shared between sites
    @redis
  end

  def self.ignore_readonly
    yield
  rescue Redis::ReadOnlyError
    Discourse.received_redis_readonly!
    nil
  end

  # prefix the key with the namespace
  def method_missing(meth, *args, **kwargs, &block)
    if @redis.respond_to?(meth)
      DiscourseRedis.ignore_readonly { @redis.public_send(meth, *args, **kwargs, &block) }
    else
      super
    end
  end

  # Proxy key methods through, but prefix the keys with the namespace
  %i[
    append
    blpop
    brpop
    brpoplpush
    decr
    decrby
    expire
    expireat
    get
    getbit
    getrange
    getset
    hdel
    hexists
    hget
    hgetall
    hincrby
    hincrbyfloat
    hkeys
    hlen
    hmget
    hmset
    hset
    hsetnx
    hvals
    incr
    incrby
    incrbyfloat
    lindex
    linsert
    llen
    lpop
    lpush
    lpushx
    lrange
    lrem
    lset
    ltrim
    mapped_hmset
    mapped_hmget
    mapped_mget
    mapped_mset
    mapped_msetnx
    move
    mset
    msetnx
    persist
    pexpire
    pexpireat
    psetex
    pttl
    rename
    renamenx
    rpop
    rpoplpush
    rpush
    rpushx
    sadd
    sadd?
    scard
    sdiff
    set
    setbit
    setex
    setnx
    setrange
    sinter
    sismember
    smembers
    sort
    spop
    srandmember
    srem
    srem?
    strlen
    sunion
    ttl
    type
    watch
    zadd
    zcard
    zcount
    zincrby
    zrange
    zrangebyscore
    zrank
    zrem
    zremrangebyrank
    zremrangebyscore
    zrevrange
    zrevrangebyscore
    zrevrank
    zrangebyscore
    dump
    restore
  ].each do |m|
    define_method m do |*args, **kwargs|
      args[0] = "#{namespace}:#{args[0]}" if @namespace
      DiscourseRedis.ignore_readonly { @redis.public_send(m, *args, **kwargs) }
    end
  end

  def exists(*args)
    args.map! { |a| "#{namespace}:#{a}" } if @namespace
    DiscourseRedis.ignore_readonly { @redis.exists(*args) }
  end

  def exists?(*args)
    args.map! { |a| "#{namespace}:#{a}" } if @namespace
    DiscourseRedis.ignore_readonly { @redis.exists?(*args) }
  end

  def mget(*args)
    args.map! { |a| "#{namespace}:#{a}" } if @namespace
    DiscourseRedis.ignore_readonly { @redis.mget(*args) }
  end

  def del(*keys)
    DiscourseRedis.ignore_readonly do
      keys = keys.flatten(1)
      keys.map! { |k| "#{namespace}:#{k}" } if @namespace
      @redis.del(*keys)
    end
  end

  def scan_each(options = {}, &block)
    DiscourseRedis.ignore_readonly do
      match = options[:match].presence || "*"

      options[:match] = if @namespace
        "#{namespace}:#{match}"
      else
        match
      end

      if block
        @redis.scan_each(**options) do |key|
          key = remove_namespace(key) if @namespace
          block.call(key)
        end
      else
        @redis
          .scan_each(**options)
          .map do |key|
            key = remove_namespace(key) if @namespace
            key
          end
      end
    end
  end

  def keys(pattern = nil)
    DiscourseRedis.ignore_readonly do
      pattern = pattern || "*"
      pattern = "#{namespace}:#{pattern}" if @namespace
      keys = @redis.keys(pattern)

      if @namespace
        len = namespace.length + 1
        keys.map! { |k| k[len..-1] }
      end

      keys
    end
  end

  def reconnect
    @redis.close
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

  def self.new_redis_store
    Cache.new
  end

  def multi
    DiscourseRedis.ignore_readonly do
      if block_given?
        @redis.multi do |transaction|
          yield DiscourseRedis.new(@config, namespace: @namespace, raw_redis: transaction)
        end
      else
        @redis.multi
      end
    end
  end

  def pipelined
    DiscourseRedis.ignore_readonly do
      if block_given?
        @redis.pipelined do |transaction|
          yield DiscourseRedis.new(@config, namespace: @namespace, raw_redis: transaction)
        end
      else
        @redis.pipelined
      end
    end
  end

  private

  def remove_namespace(key)
    key[(namespace.length + 1)..-1]
  end

  class EvalHelper
    def initialize(script)
      @script = script
      @sha1 = Digest::SHA1.hexdigest(script)
    end

    def eval(redis, *args, **kwargs)
      redis.evalsha @sha1, *args, **kwargs
    rescue ::Redis::CommandError => e
      if e.to_s =~ /\ANOSCRIPT/
        redis.eval @script, *args, **kwargs
      else
        raise
      end
    end
  end
end
