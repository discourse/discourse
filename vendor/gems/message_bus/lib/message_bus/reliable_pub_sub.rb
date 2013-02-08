require 'redis'
# the heart of the message bus, it acts as 2 things 
#
# 1. A channel multiplexer
# 2. Backlog storage per-multiplexed channel. 
#
# ids are all sequencially increasing numbers starting at 0 
#


class MessageBus::ReliablePubSub

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

  def offset_key(channel)
    "__mb_offset_#{channel}"
  end

  def backlog_key(channel)
    "__mb_backlog_#{channel}"
  end

  def global_id_key
    "__mb_global_id"
  end

  def global_backlog_key
    "__mb_global_backlog"
  end
  
  def global_offset_key
    "__mb_global_offset"
  end

  # use with extreme care, will nuke all of the data
  def reset! 
    pub_redis.keys("__mb_*").each do |k|
      pub_redis.del k
    end
  end

  def publish(channel, data)
    redis = pub_redis 
    offset_key = offset_key(channel)
    backlog_key = backlog_key(channel)

    redis.watch(offset_key, backlog_key, global_id_key, global_backlog_key, global_offset_key) do
      offset = redis.get(offset_key).to_i
      backlog = redis.llen(backlog_key).to_i

      global_offset = redis.get(global_offset_key).to_i
      global_backlog = redis.llen(global_backlog_key).to_i

      global_id = redis.get(global_id_key).to_i
      global_id += 1

      too_big = backlog + 1 > @max_backlog_size
      global_too_big = global_backlog + 1 > @max_global_backlog_size

      message_id = backlog + offset + 1 
      redis.multi do 
        if too_big
          redis.ltrim backlog_key, (backlog+1) - @max_backlog_size, -1
          offset += (backlog+1) - @max_backlog_size
          redis.set(offset_key, offset)
        end

        if global_too_big
          redis.ltrim global_backlog_key, (global_backlog+1) - @max_global_backlog_size, -1
          global_offset += (global_backlog+1) - @max_global_backlog_size
          redis.set(global_offset_key, global_offset)
        end

        msg = MessageBus::Message.new global_id, message_id, channel, data
        payload = msg.encode

        redis.set global_id_key, global_id
        redis.rpush backlog_key, payload
        redis.rpush global_backlog_key, message_id.to_s << "|" << channel
        redis.publish redis_channel_name, payload
      end

      return message_id
    end
  end

  def last_id(channel)
    redis = pub_redis 
    offset_key = offset_key(channel)
    backlog_key = backlog_key(channel)
    
    offset,len = nil
    redis.watch offset_key, backlog_key do 
      offset = redis.get(offset_key).to_i
      len = redis.llen backlog_key
    end
    offset + len
  end

  def backlog(channel, last_id = nil)
    redis = pub_redis 
    offset_key = offset_key(channel)
    backlog_key = backlog_key(channel)

    items = nil

    redis.watch offset_key, backlog_key do 
      offset = redis.get(offset_key).to_i
      start_at = last_id.to_i - offset
      items = redis.lrange backlog_key, start_at, -1
    end

    items.map do |i|
      MessageBus::Message.decode(i)
    end
  end

  def global_backlog(last_id = nil)
    last_id = last_id.to_i
    items = nil
    redis = pub_redis

    redis.watch global_backlog_key, global_offset_key do 
      offset = redis.get(global_offset_key).to_i
      start_at = last_id.to_i - offset
      items = redis.lrange global_backlog_key, start_at, -1
    end

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
    offset_key = offset_key(channel)
    backlog_key = backlog_key(channel)

    msg = nil
    redis.watch(offset_key, backlog_key) do
      offset = redis.get(offset_key).to_i
      idx = (message_id-1) - offset
      return nil if idx < 0 
      msg = redis.lindex(backlog_key, idx)
    end

    if msg 
      msg = MessageBus::Message.decode(msg)
    end
    msg
  end

  def subscribe(channel, last_id = nil)
    # trivial implementation for now, 
    #   can cut down on connections if we only have one global subscriber 
    raise ArgumentError unless block_given?

    global_subscribe(last_id) do |m|
      yield m if m.channel == channel
    end
  end

  def global_subscribe(last_id=nil, &blk)
    raise ArgumentError unless block_given?
    highest_id = last_id

    clear_backlog = lambda do 
      global_backlog(highest_id).each do |old|
        highest_id = old.global_id
        yield old
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
          if highest_id && m.global_id != highest_id + 1
            clear_backlog.call(&blk)
          end
          yield m if highest_id.nil? || m.global_id > highest_id
          highest_id = m.global_id
        end
      end
    rescue => error
      MessageBus.logger.warn "#{error} subscribe failed, reconnecting in 1 second. Call stack #{error.backtrace}"
      sleep 1
      retry
    end
  end


end
