# frozen_string_literal: true

# The server-side implementation of PresenceChannels. See also {PresenceController}
# and +app/assets/javascripts/discourse/app/services/presence.js+
class PresenceChannel
  class NotFound < StandardError
  end

  class InvalidAccess < StandardError
  end

  class ConfigNotLoaded < StandardError
  end

  class InvalidConfig < StandardError
  end

  class State
    include ActiveModel::Serialization

    attr_reader :message_bus_last_id
    attr_reader :user_ids
    attr_reader :count

    def initialize(message_bus_last_id:, user_ids: nil, count: nil)
      raise "user_ids or count required" if user_ids.nil? && count.nil?
      @message_bus_last_id = message_bus_last_id
      @user_ids = user_ids
      @count = count || user_ids.count
    end

    def users
      return nil if user_ids.nil?
      User.where(id: user_ids)
    end
  end

  # Class for managing config of PresenceChannel
  # Three parameters can be provided on initialization:
  #   public: boolean value. If true, channel information is visible to all users (default false)
  #   allowed_user_ids: array of user_ids that can view, and become present in, the channel (default [])
  #   allowed_group_ids: array of group_ids that can view, and become present in, the channel (default [])
  #   count_only: boolean. If true, user identities are never revealed to clients. (default [])
  class Config
    NOT_FOUND = "notfound"

    attr_accessor :public, :allowed_user_ids, :allowed_group_ids, :count_only, :timeout

    def initialize(
      public: false,
      allowed_user_ids: nil,
      allowed_group_ids: nil,
      count_only: false,
      timeout: nil
    )
      @public = public
      @allowed_user_ids = allowed_user_ids
      @allowed_group_ids = allowed_group_ids
      @count_only = count_only
      @timeout = timeout
    end

    def self.from_json(json)
      data = JSON.parse(json, symbolize_names: true)
      data = {} if !data.is_a? Hash
      new(**data.slice(:public, :allowed_user_ids, :allowed_group_ids, :count_only, :timeout))
    end

    def to_json
      data = { public: public }
      data[:allowed_user_ids] = allowed_user_ids if allowed_user_ids
      data[:allowed_group_ids] = allowed_group_ids if allowed_group_ids
      data[:count_only] = count_only if count_only
      data[:timeout] = timeout if timeout
      data.to_json
    end
  end

  DEFAULT_TIMEOUT = 60
  CONFIG_CACHE_SECONDS = 10
  GC_SECONDS = 24.hours.to_i
  MUTEX_TIMEOUT_SECONDS = 10
  MUTEX_LOCKED_ERROR = "PresenceChannel mutex is locked"

  @@configuration_blocks ||= {}

  attr_reader :name, :timeout, :message_bus_channel_name, :config

  def initialize(name, raise_not_found: true, use_cache: true)
    @name = name
    @message_bus_channel_name = "/presence#{name}"

    begin
      @config = fetch_config(use_cache: use_cache)
    rescue PresenceChannel::NotFound
      raise if raise_not_found
      @config = Config.new
    end

    @timeout = config.timeout || DEFAULT_TIMEOUT
  end

  # Is this user allowed to view this channel?
  # Pass `nil` for anonymous viewers
  def can_view?(user_id: nil, group_ids: nil)
    return true if config.public
    return true if user_id && config.allowed_user_ids&.include?(user_id)

    if user_id && config.allowed_group_ids.present?
      return true if config.allowed_group_ids.include?(Group::AUTO_GROUPS[:everyone])
      group_ids ||= GroupUser.where(user_id: user_id).pluck("group_id")
      return true if (group_ids & config.allowed_group_ids).present?
    end
    false
  end

  # Is a user allowed to enter this channel?
  # Currently equal to the can_view? permission
  def can_enter?(user_id: nil, group_ids: nil)
    return false if user_id.nil?
    can_view?(user_id: user_id, group_ids: group_ids)
  end

  # Mark a user's client as present in this channel. The client_id should be unique per
  # browser tab. This method should be called repeatedly (at least once every DEFAULT_TIMEOUT)
  # while the user is present in the channel.
  def present(user_id:, client_id:)
    raise PresenceChannel::InvalidAccess if !can_enter?(user_id: user_id)

    mutex_value = SecureRandom.hex
    result =
      retry_on_mutex_error do
        PresenceChannel.redis_eval(
          :present,
          redis_keys,
          [name, user_id, client_id, (Time.zone.now + timeout).to_i, mutex_value],
        )
      end

    if result == 1
      begin
        publish_message(entering_user_ids: [user_id])
      ensure
        release_mutex(mutex_value)
      end
    end
  end

  # Immediately mark a user's client as leaving the channel
  def leave(user_id:, client_id:)
    mutex_value = SecureRandom.hex
    result =
      retry_on_mutex_error do
        PresenceChannel.redis_eval(:leave, redis_keys, [name, user_id, client_id, nil, mutex_value])
      end

    if result == 1
      begin
        publish_message(leaving_user_ids: [user_id])
      ensure
        release_mutex(mutex_value)
      end
    end
  end

  # Fetch a {PresenceChannel::State} instance representing the current state of this
  #
  # @param [Boolean] count_only set true to skip fetching the list of user ids from redis
  def state(count_only: config.count_only)
    if count_only
      last_id, count = retry_on_mutex_error { PresenceChannel.redis_eval(:count, redis_keys) }
    else
      last_id, ids = retry_on_mutex_error { PresenceChannel.redis_eval(:user_ids, redis_keys) }
    end
    count ||= ids&.count
    last_id = nil if last_id == -1

    if Rails.env.test? && MessageBus.backend == :memory
      # Doing it this way is not atomic, but we have no other option when
      # messagebus is not using the redis backend
      last_id = MessageBus.last_id(message_bus_channel_name)
    end

    State.new(message_bus_last_id: last_id, user_ids: ids, count: count)
  end

  def user_ids
    state.user_ids
  end

  def count
    state(count_only: true).count
  end

  # Automatically expire all users which have not been 'present' for more than +DEFAULT_TIMEOUT+
  def auto_leave
    mutex_value = SecureRandom.hex
    left_user_ids =
      retry_on_mutex_error do
        PresenceChannel.redis_eval(:auto_leave, redis_keys, [name, Time.zone.now.to_i, mutex_value])
      end

    if !left_user_ids.empty?
      begin
        publish_message(leaving_user_ids: left_user_ids)
      ensure
        release_mutex(mutex_value)
      end
    end
  end

  # Clear all members of the channel. This is intended for debugging/development only
  def clear
    PresenceChannel.redis.del(redis_key_zlist)
    PresenceChannel.redis.del(redis_key_hash)
    PresenceChannel.redis.del(redis_key_config)
    PresenceChannel.redis.del(redis_key_mutex)
    PresenceChannel.redis.zrem(self.class.redis_key_channel_list, name)
  end

  # Designed to be run periodically. Checks the channel list for channels with expired members,
  # and runs auto_leave for each eligible channel
  def self.auto_leave_all
    channels_with_expiring_members =
      PresenceChannel.redis.zrangebyscore(redis_key_channel_list, "-inf", Time.zone.now.to_i)
    channels_with_expiring_members.each { |name| new(name, raise_not_found: false).auto_leave }
  end

  # Clear all known channels. This is intended for debugging/development only
  def self.clear_all!
    channels = PresenceChannel.redis.zrangebyscore(redis_key_channel_list, "-inf", "+inf")
    channels.each { |name| new(name, raise_not_found: false).clear }

    config_cache_keys =
      PresenceChannel
        .redis
        .scan_each(match: Discourse.redis.namespace_key("_presence_*_config"))
        .to_a
    PresenceChannel.redis.del(*config_cache_keys) if config_cache_keys.present?
  end

  # Shortcut to access a redis client for all PresenceChannel activities.
  # PresenceChannel must use the same Redis server as MessageBus, so that
  # actions can be applied atomically. For the vast majority of Discourse
  # installations, this is the same Redis server as `Discourse.redis`.
  def self.redis
    if MessageBus.backend == :redis
      MessageBus.backend_instance.send(:pub_redis) # TODO: avoid a private API?
    elsif Rails.env.test?
      Discourse.redis.without_namespace
    else
      raise "PresenceChannel is unable to access MessageBus's Redis instance"
    end
  end

  def self.redis_eval(key, *args)
    @@lua_scripts[key].eval(redis, *args)
  end

  # Register a callback to configure channels with a given prefix
  # Prefix must match [a-zA-Z0-9_-]+
  #
  # For example, this registration will be used for
  # all channels starting /topic-reply/...:
  #
  #     register_prefix("topic-reply") do |channel_name|
  #       PresenceChannel::Config.new(public: true)
  #     end
  #
  # At runtime, the block will be passed a full channel name. If the channel
  # should not exist, the block should return `nil`. If the channel should exist,
  # the block should return a PresenceChannel::Config object.
  #
  # Return values may be cached for up to 10 seconds.
  #
  # Plugins should use the {Plugin::Instance.register_presence_channel_prefix} API instead
  def self.register_prefix(prefix, &block)
    unless prefix.match? /[a-zA-Z0-9_-]+/
      raise "PresenceChannel prefix #{prefix} must match [a-zA-Z0-9_-]+"
    end
    if @@configuration_blocks&.[](prefix)
      raise "PresenceChannel prefix #{prefix} already registered"
    end
    @@configuration_blocks[prefix] = block
  end

  # For use in a test environment only
  def self.unregister_prefix(prefix)
    raise "Only allowed in test environment" if !Rails.env.test?
    @@configuration_blocks&.delete(prefix)
  end

  private

  def fetch_config(use_cache: true)
    cached_config = (PresenceChannel.redis.get(redis_key_config) if use_cache)

    if cached_config == Config::NOT_FOUND
      raise PresenceChannel::NotFound
    elsif cached_config
      Config.from_json(cached_config)
    else
      prefix = name[%r{/([a-zA-Z0-9_-]+)/.*}, 1]
      raise PresenceChannel::NotFound if prefix.nil?

      config_block = @@configuration_blocks[prefix]
      config_block ||=
        DiscoursePluginRegistry.presence_channel_prefixes.find { |t| t[0] == prefix }&.[](1)
      raise PresenceChannel::NotFound if config_block.nil?

      result = config_block.call(name)
      to_cache =
        if result.is_a? Config
          result.to_json
        elsif result.nil?
          Config::NOT_FOUND
        else
          raise InvalidConfig.new "Expected PresenceChannel::Config or nil. Got a #{result.class.name}"
        end

      DiscourseRedis.ignore_readonly do
        PresenceChannel.redis.set(redis_key_config, to_cache, ex: CONFIG_CACHE_SECONDS)
      end

      raise PresenceChannel::NotFound if result.nil?
      result
    end
  end

  def publish_message(entering_user_ids: nil, leaving_user_ids: nil)
    message = {}
    if config.count_only
      message["count_delta"] = entering_user_ids&.count || 0
      message["count_delta"] -= leaving_user_ids&.count || 0
      return if message["count_delta"] == 0
    else
      message["leaving_user_ids"] = leaving_user_ids if leaving_user_ids.present?
      if entering_user_ids.present?
        users = User.where(id: entering_user_ids).includes(:user_option)
        message["entering_users"] = ActiveModel::ArraySerializer.new(
          users,
          each_serializer: BasicUserSerializer,
        )
      end
    end

    params = {}

    if config.public
      # no params required
    elsif config.allowed_user_ids || config.allowed_group_ids
      params[:user_ids] = config.allowed_user_ids
      params[:group_ids] = config.allowed_group_ids
    else
      # nobody is allowed... don't publish anything
      return
    end

    MessageBus.publish(message_bus_channel_name, message.as_json, **params)
  end

  # Most atomic actions are achieved via lua scripts. However, when a lua action
  # will result in publishing a messagebus message, the atomicity is broken.
  #
  # For example, if one process is handling a 'user enter' event, and another is
  # handling a 'user leave' event, we need to make sure the messagebus messages
  # are published in the same sequence that the PresenceChannel lua script are run.
  #
  # The present/leave/auto_leave lua scripts will automatically acquire this mutex
  # if needed. If their return value indicates a change has occurred, the mutex
  # should be released via #release_mutex after the messagebus message has been sent
  #
  # If they need a change, and the mutex is not available, they will raise an error
  # and should be retried periodically
  def redis_key_mutex
    Discourse.redis.namespace_key("_presence_#{name}_mutex")
  end

  def release_mutex(mutex_value)
    PresenceChannel.redis_eval(:release_mutex, [redis_key_mutex], [mutex_value])
  end

  def retry_on_mutex_error
    attempts ||= 0
    yield
  rescue ::Redis::CommandError => e
    if e.to_s =~ /#{MUTEX_LOCKED_ERROR}/ && attempts < 1000
      attempts += 1
      sleep 0.001
      retry
    else
      raise
    end
  end

  # The redis key which MessageBus uses to store the 'last_id' for the channel
  # associated with this PresenceChannel.
  def message_bus_last_id_key
    return "" if Rails.env.test? && MessageBus.backend == :memory

    # TODO: Avoid using private MessageBus methods here
    encoded_channel_name = MessageBus.send(:encode_channel_name, message_bus_channel_name)
    MessageBus.backend_instance.send(:backlog_id_key, encoded_channel_name)
  end

  def redis_keys
    [
      redis_key_zlist,
      redis_key_hash,
      self.class.redis_key_channel_list,
      message_bus_last_id_key,
      redis_key_mutex,
    ]
  end

  # The zlist is a list of client_ids, ranked by their expiration timestamp
  # we periodically delete the 'lowest ranked' items in this list based on the `timeout` of the channel
  def redis_key_zlist
    Discourse.redis.namespace_key("_presence_#{name}_zlist")
  end

  # The hash contains a map of user_id => session_count
  # when the count for a user reaches 0, the key is deleted
  # We use this hash to efficiently count the number of present users
  def redis_key_hash
    Discourse.redis.namespace_key("_presence_#{name}_hash")
  end

  # The hash contains a map of user_id => session_count
  # when the count for a user reaches 0, the key is deleted
  # We use this hash to efficiently count the number of present users
  def redis_key_config
    Discourse.redis.namespace_key("_presence_#{name}_config")
  end

  # This list contains all active presence channels, ranked with the expiration timestamp of their least-recently-seen  client_id
  # We periodically check the 'lowest ranked' items in this list based on the `timeout` of the channel
  def self.redis_key_channel_list
    Discourse.redis.namespace_key("_presence_channels")
  end

  COMMON_PRESENT_LEAVE_LUA = <<~LUA
    local channel = ARGV[1]
    local user_id = ARGV[2]
    local client_id = ARGV[3]
    local expires = ARGV[4]
    local mutex_value = ARGV[5]

    local zlist_key = KEYS[1]
    local hash_key = KEYS[2]
    local channels_key = KEYS[3]
    local message_bus_id_key = KEYS[4]
    local mutex_key = KEYS[5]

    local mutex_locked = redis.call('EXISTS', mutex_key) == 1

    local zlist_elem = tostring(user_id) .. " " .. tostring(client_id)
  LUA

  UPDATE_GLOBAL_CHANNELS_LUA = <<~LUA
    -- Update the global channels list with the timestamp of the oldest client
    local oldest_client = redis.call('ZRANGE', zlist_key, 0, 0, 'WITHSCORES')
    if table.getn(oldest_client) > 0 then
      local oldest_client_expire_timestamp = oldest_client[2]
      redis.call('ZADD', channels_key, tonumber(oldest_client_expire_timestamp), tostring(channel))
    else
      -- The channel is now empty, delete from global list
      redis.call('ZREM', channels_key, tostring(channel))
    end
  LUA

  @@lua_scripts = {}

  @@lua_scripts[:present] = DiscourseRedis::EvalHelper.new <<~LUA
    #{COMMON_PRESENT_LEAVE_LUA}

    if mutex_locked then
      local mutex_required = redis.call('HGET', hash_key, tostring(user_id)) == false
      if mutex_required then
        error("#{MUTEX_LOCKED_ERROR}")
      end
    end

    local added_clients = redis.call('ZADD', zlist_key, expires, zlist_elem)
    local added_users = 0
    if tonumber(added_clients) > 0 then
      local new_count = redis.call('HINCRBY', hash_key, tostring(user_id), 1)
      if new_count == 1 then
        added_users = 1
        redis.call('SET', mutex_key, mutex_value, 'EX', #{MUTEX_TIMEOUT_SECONDS})
      end
      -- Add the channel to the global channel list. 'NX' means the value will
      -- only be set if doesn't already exist
      redis.call('ZADD', channels_key, "NX", expires, tostring(channel))
    end

    redis.call('EXPIREAT', hash_key, expires + #{GC_SECONDS})
    redis.call('EXPIREAT', zlist_key, expires + #{GC_SECONDS})

    return added_users
  LUA

  @@lua_scripts[:leave] = DiscourseRedis::EvalHelper.new <<~LUA
    #{COMMON_PRESENT_LEAVE_LUA}

    if mutex_locked then
      local user_session_count = redis.call('HGET', hash_key, tostring(user_id))
      local mutex_required = user_session_count == 1 and redis.call('ZRANK', zlist_key, zlist_elem) ~= false
      if mutex_required then
        error("#{MUTEX_LOCKED_ERROR}")
      end
    end

    -- Remove the user from the channel zlist
    local removed_clients = redis.call('ZREM', zlist_key, zlist_elem)

    local removed_users = 0
    if tonumber(removed_clients) > 0 then
      #{UPDATE_GLOBAL_CHANNELS_LUA}

      -- Update the user session count in the channel hash
      local val = redis.call('HINCRBY', hash_key, user_id, #{Discourse::SYSTEM_USER_ID})
      if val <= 0 then
        redis.call('HDEL', hash_key, user_id)
        removed_users = 1
        redis.call('SET', mutex_key, mutex_value, 'EX', #{MUTEX_TIMEOUT_SECONDS})
      end
    end

    return removed_users
  LUA

  @@lua_scripts[:release_mutex] = DiscourseRedis::EvalHelper.new <<~LUA
    local mutex_key = KEYS[1]
    local expected_value = ARGV[1]

    if redis.call("GET", mutex_key) == expected_value then
      redis.call("DEL", mutex_key)
    end
  LUA

  @@lua_scripts[:user_ids] = DiscourseRedis::EvalHelper.new <<~LUA
    local zlist_key = KEYS[1]
    local hash_key = KEYS[2]
    local message_bus_id_key = KEYS[4]
    local mutex_key = KEYS[5]

    if redis.call('EXISTS', mutex_key) > 0 then
      error('#{MUTEX_LOCKED_ERROR}')
    end

    local user_ids = redis.call('HKEYS', hash_key)
    table.foreach(user_ids, function(k,v) user_ids[k] = tonumber(v) end)

    local message_bus_id = tonumber(redis.call('GET', message_bus_id_key))
    if message_bus_id == nil then
      message_bus_id = -1
    end

    return { message_bus_id, user_ids }
  LUA

  @@lua_scripts[:count] = DiscourseRedis::EvalHelper.new <<~LUA
    local zlist_key = KEYS[1]
    local hash_key = KEYS[2]
    local message_bus_id_key = KEYS[4]
    local mutex_key = KEYS[5]

    if redis.call('EXISTS', mutex_key) > 0 then
      error('#{MUTEX_LOCKED_ERROR}')
    end

    local message_bus_id = tonumber(redis.call('GET', message_bus_id_key))
    if message_bus_id == nil then
      message_bus_id = -1
    end

    local count = redis.call('HLEN', hash_key)

    return { message_bus_id, count }
  LUA

  @@lua_scripts[:auto_leave] = DiscourseRedis::EvalHelper.new <<~LUA
    local zlist_key = KEYS[1]
    local hash_key = KEYS[2]
    local channels_key = KEYS[3]
    local mutex_key = KEYS[5]
    local channel = ARGV[1]
    local time = ARGV[2]
    local mutex_value = ARGV[3]

    local expire = redis.call('ZRANGEBYSCORE', zlist_key, '-inf', time)

    local has_mutex = false

    local get_mutex = function()
      if redis.call('SETNX', mutex_key, mutex_value) == 0 then
        error("#{MUTEX_LOCKED_ERROR}")
      end
      redis.call('EXPIRE', mutex_key, #{MUTEX_TIMEOUT_SECONDS})
      has_mutex = true
    end

    local expired_user_ids = {}

    local expireOld = function(k, v)
      local user_id = v:match("[^ ]+")

      if (not has_mutex) and (tonumber(redis.call('HGET', hash_key, user_id)) == 1) then
        get_mutex()
      end

      local val = redis.call('HINCRBY', hash_key, user_id, #{Discourse::SYSTEM_USER_ID})
      if val <= 0 then
        table.insert(expired_user_ids, tonumber(user_id))
        redis.call('HDEL', hash_key, user_id)
      end
      redis.call('ZREM', zlist_key, v)
    end

    table.foreach(expire, expireOld)

    #{UPDATE_GLOBAL_CHANNELS_LUA}

    return expired_user_ids
  LUA
end
