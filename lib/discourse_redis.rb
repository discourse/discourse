#
#  A wrapper around redis that namespaces keys with the current site id
#
class DiscourseRedis

  def self.raw_connection(config = nil)
    config ||= self.config
    redis_opts = {host: config['host'], port: config['port'], db: config['db']}
    redis_opts[:password] = config['password'] if config['password']
    Redis.new(redis_opts)
  end

  def self.config
    @config ||= YAML.load(ERB.new(File.new("#{Rails.root}/config/redis.yml").read).result)[Rails.env]
  end

  def self.url(config=nil)
    config ||= self.config
    "redis://#{(':' + config['password'] + '@') if config['password']}#{config['host']}:#{config['port']}/#{config['db']}"
  end

  def initialize
    @config = DiscourseRedis.config
    @redis = DiscourseRedis.raw_connection(@config)
  end

  def url
    self.class.url(@config)
  end

  # prefix the key with the namespace
  def method_missing(meth, *args, &block)
    if @redis.respond_to?(meth)
      @redis.send(meth, *args, &block)
    else
      super
    end
  end

  # Proxy key methods through, but prefix the keys with the namespace
  [:append, :blpop, :brpop, :brpoplpush, :decr, :decrby, :del, :exists, :expire, :expireat, :get, :getbit, :getrange, :getset,
   :hdel, :hexists, :hget, :hgetall, :hincrby, :hincrbyfloat, :hkeys, :hlen, :hmget, :hmset, :hset, :hsetnx, :hvals, :incr,
   :incrby, :incrbyfloat, :lindex, :linsert, :llen, :lpop, :lpush, :lpushx, :lrange, :lrem, :lset, :ltrim, :mget, :move, :mset,
   :msetnx, :persist, :pexpire, :pexpireat, :psetex, :pttl, :rename, :renamenx, :rpop, :rpoplpush, :rpush, :rpushx, :sadd, :scard,
   :sdiff, :set, :setbit, :setex, :setnx, :setrange, :sinter, :sismember, :smembers, :sort, :spop, :srandmember, :srem, :strlen,
   :sunion, :ttl, :type, :watch, :zadd, :zcard, :zcount, :zincrby, :zrange, :zrangebyscore, :zrank, :zrem, :zremrangebyrank,
   :zremrangebyscore, :zrevrange, :zrevrangebyscore, :zrevrank, :zrangebyscore].each do |m|
    define_method m do |*args|
      args[0] = "#{DiscourseRedis.namespace}:#{args[0]}"
      @redis.send(m, *args)
    end
  end

  def self.namespace
    RailsMultisite::ConnectionManagement.current_db
  end

  def self.new_redis_store
    redis_config = YAML.load(ERB.new(File.new("#{Rails.root}/config/redis.yml").read).result)[Rails.env]
    unless redis_config
      puts '', "Redis config for environment '#{Rails.env}' was not found in #{Rails.root}/config/redis.yml."
      puts "Did you forget to do RAILS_ENV=production?"
      puts "Check your redis.yml and make sure it has configuration for the environment you're trying to use.", ''
      raise 'Redis config not found'
    end
    redis_store = ActiveSupport::Cache::RedisStore.new "redis://#{(':' + redis_config['password'] + '@') if redis_config['password']}#{redis_config['host']}:#{redis_config['port']}/#{redis_config['cache_db']}"
    redis_store.options[:namespace] = -> { DiscourseRedis.namespace }
    redis_store
  end


end
