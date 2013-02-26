#
#  A wrapper around redis that namespaces keys with the current site id
#
class DiscourseRedis

  def initialize
    @config = YAML::load(File.open("#{Rails.root}/config/redis.yml"))[Rails.env]
    redis_opts = {:host => @config['host'], :port => @config['port'], :db => @config['db']}
    @redis = Redis.new(redis_opts)
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
  %w(append blpop brpop brpoplpush decr decrby del exists expire expireat get getbit getrange getset hdel
       hexists hget hgetall hincrby hincrbyfloat hkeys hlen hmget hmset hset hsetnx hvals incr incrby incrbyfloat
       lindex linsert llen lpop lpush lpushx lrange lrem lset ltrim mget move mset msetnx persist pexpire pexpireat psetex
       pttl rename renamenx rpop rpoplpush rpush rpushx sadd scard sdiff set setbit setex setnx setrange sinter
       sismember smembers sort spop srandmember srem strlen sunion ttl type watch zadd zcard zcount zincrby
       zrange zrangebyscore zrank zrem zremrangebyrank zremrangebyscore zrevrange zrevrangebyscore zrevrank zrangebyscore).each do |m|
    define_method m do |*args|
      args[0] = "#{DiscourseRedis.namespace}:#{args[0]}"
      @redis.send(__method__, *args)
    end
  end

  def self.namespace
    RailsMultisite::ConnectionManagement.current_db
  end

  def url
    "redis://#{@config['host']}:#{@config['port']}/#{@config['db']}"
  end

end
