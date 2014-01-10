#
#  A wrapper around redis that namespaces keys with the current site id
#
require_dependency 'cache'
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

  def without_namespace
    # Only use this if you want to store and fetch data that's shared between sites
    @redis
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
  [:append, :blpop, :brpop, :brpoplpush, :decr, :decrby, :exists, :expire, :expireat, :get, :getbit, :getrange, :getset,
   :hdel, :hexists, :hget, :hgetall, :hincrby, :hincrbyfloat, :hkeys, :hlen, :hmget, :hmset, :hset, :hsetnx, :hvals, :incr,
   :incrby, :incrbyfloat, :lindex, :linsert, :llen, :lpop, :lpush, :lpushx, :lrange, :lrem, :lset, :ltrim,
   :mapped_hmset, :mapped_hmget, :mapped_mget, :mapped_mset, :mapped_msetnx, :mget, :move, :mset,
   :msetnx, :persist, :pexpire, :pexpireat, :psetex, :pttl, :rename, :renamenx, :rpop, :rpoplpush, :rpush, :rpushx, :sadd, :scard,
   :sdiff, :set, :setbit, :setex, :setnx, :setrange, :sinter, :sismember, :smembers, :sort, :spop, :srandmember, :srem, :strlen,
   :sunion, :ttl, :type, :watch, :zadd, :zcard, :zcount, :zincrby, :zrange, :zrangebyscore, :zrank, :zrem, :zremrangebyrank,
   :zremrangebyscore, :zrevrange, :zrevrangebyscore, :zrevrank, :zrangebyscore].each do |m|
    define_method m do |*args|
      args[0] = "#{DiscourseRedis.namespace}:#{args[0]}"
      @redis.send(m, *args)
    end
  end

  def del(k)
    k = "#{DiscourseRedis.namespace}:#{k}"
    @redis.del k
  end

  def keys
    len = DiscourseRedis.namespace.length + 1
    @redis.keys("#{DiscourseRedis.namespace}:*").map{
      |k| k[len..-1]
    }
  end

  def flushdb
    keys.each{|k| del(k)}
  end

  def reconnect
    @redis.client.reconnect
  end

  def self.namespace
    RailsMultisite::ConnectionManagement.current_db
  end

  def self.new_redis_store
    Cache.new
  end

end
