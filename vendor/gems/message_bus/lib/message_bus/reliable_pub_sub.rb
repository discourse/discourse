require 'redis'
# the heart of the message bus, it acts as 2 things
#
# 1. A channel multiplexer
# 2. Backlog storage per-multiplexed channel.
#
# ids are all sequencially increasing numbers starting at 0
#


class MessageBus::ReliablePubSub

  class NoMoreRetries < StandardError; end
  class BackLogOutOfOrder < StandardError
    attr_accessor :highest_id

    def initialize(highest_id)
      @highest_id = highest_id
    end
  end

  def max_publish_retries=(val)
    @max_publish_retries = val
  end

  def max_publish_retries
    @max_publish_retries ||= 10
  end

  def max_publish_wait=(ms)
    @max_publish_wait = ms
  end

  def max_publish_wait
    @max_publish_wait ||= 500
  end

  # max_backlog_size is per multiplexed channel
  def initialize(redis_config = {}, max_backlog_size = 1000)
    @redis_config = redis_config
    @max_backlog_size = 1000
    # we can store a ton here ...
    @max_global_backlog_size = 100000
  end

  # amount of global backlog we can spin through
  def max_global_backlog_size=(val)
    @max_global_backlog_size = val
  end

  # per channel backlog size
  def max_backlog_size=(val)
    @max_backlog_size = val
  end

  def new_redis_connection
    ::Redis.new(@redis_config)
  end

  def redis_channel_name
    db = @redis_config[:db] || 0
    "discourse_#{db}"
  end

  # redis connection used for publishing messages
  def pub_redis
    @pub_redis ||= new_redis_connection
  end

  def backlog_key(channel)
    "__mb_backlog_n_#{channel}"
  end

  def backlog_id_key(channel)
    "__mb_backlog_id_n_#{channel}"
  end

  def global_id_key
    "__mb_global_id_n"
  end

  def global_backlog_key
    "__mb_global_backlog_n"
  end

  # use with extreme care, will nuke all of the data
  def reset!
    pub_redis.keys("__mb_*").each do |k|
      pub_redis.del k
    end
  end

  def publish(channel, data)
    redis = pub_redis
    backlog_id_key = backlog_id_key(channel)
    backlog_key = backlog_key(channel)

    global_id = nil
    backlog_id = nil

    redis.multi do |m|
      global_id = m.incr(global_id_key)
      backlog_id = m.incr(backlog_id_key)
    end

    global_id = global_id.value
    backlog_id = backlog_id.value

    msg = MessageBus::Message.new global_id, backlog_id, channel, data
    payload = msg.encode

    redis.zadd backlog_key, backlog_id, payload
    redis.zadd global_backlog_key, global_id, backlog_id.to_s << "|" << channel

    redis.publish redis_channel_name, payload

    if backlog_id > @max_backlog_size
      redis.zremrangebyscore backlog_key, 1, backlog_id - @max_backlog_size
    end

    if global_id > @max_global_backlog_size
      redis.zremrangebyscore global_backlog_key, 1, backlog_id - @max_backlog_size
    end

    backlog_id
  end

  def last_id(channel)
    redis = pub_redis
    backlog_id_key = backlog_id_key(channel)
    redis.get(backlog_id_key).to_i
  end

  def backlog(channel, last_id = nil)
    redis = pub_redis
    backlog_key = backlog_key(channel)
    items = redis.zrangebyscore backlog_key, last_id.to_i + 1, "+inf"

    items.map do |i|
      MessageBus::Message.decode(i)
    end
  end

  def global_backlog(last_id = nil)
    last_id = last_id.to_i
    redis = pub_redis

    items = redis.zrangebyscore global_backlog_key, last_id.to_i + 1, "+inf"

    items.map! do |i|
      pipe = i.index "|"
      message_id = i[0..pipe].to_i
      channel = i[pipe+1..-1]
      m = get_message(channel, message_id)
      m
    end

    items.compact!
    items
  end

  def get_message(channel, message_id)
    redis = pub_redis
    backlog_key = backlog_key(channel)

    items = redis.zrangebyscore backlog_key, message_id, message_id
    if items && items[0]
      MessageBus::Message.decode(items[0])
    else
      nil
    end
  end

  def subscribe(channel, last_id = nil)
    # trivial implementation for now,
    #   can cut down on connections if we only have one global subscriber
    raise ArgumentError unless block_given?

    if last_id
      # we need to translate this to a global id, at least give it a shot
      #   we are subscribing on global and global is always going to be bigger than local
      #   so worst case is a replay of a few messages
      message = get_message(channel, last_id)
      if message
        last_id = message.global_id
      end
    end
    global_subscribe(last_id) do |m|
      yield m if m.channel == channel
    end
  end

  def process_global_backlog(highest_id, raise_error, &blk)
    global_backlog(highest_id).each do |old|
      if highest_id + 1 == old.global_id
        yield old
        highest_id = old.global_id
      else
        raise BackLogOutOfOrder.new(highest_id) if raise_error
        if old.global_id > highest_id
          yield old
          highest_id = old.global_id
        end
      end
    end
    highest_id
  end

  def global_subscribe(last_id=nil, &blk)
    raise ArgumentError unless block_given?
    highest_id = last_id

    clear_backlog = lambda do
      retries = 4
      begin
        highest_id = process_global_backlog(highest_id, retries > 0, &blk)
      rescue BackLogOutOfOrder => e
        highest_id = e.highest_id
        retries -= 1
        sleep(rand(50) / 1000.0)
        retry
      end
    end


    begin
      redis = new_redis_connection

      if highest_id
        clear_backlog.call(&blk)
      end

      redis.subscribe(redis_channel_name) do |on|
        on.subscribe do
          if highest_id
            clear_backlog.call(&blk)
          end
        end
        on.message do |c,m|
          m = MessageBus::Message.decode m

          # we have 2 options
          #
          # 1. message came in the correct order GREAT, just deal with it
          # 2. message came in the incorrect order COMPLICATED, wait a tiny bit and clear backlog

          if highest_id.nil? || m.global_id == highest_id + 1
            highest_id = m.global_id
            yield m
          else
            clear_backlog.call(&blk)
          end
        end
      end
    rescue => error
      MessageBus.logger.warn "#{error} subscribe failed, reconnecting in 1 second. Call stack #{error.backtrace}"
      sleep 1
      retry
    end
  end

end
