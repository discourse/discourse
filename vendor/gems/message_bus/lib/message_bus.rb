# require 'thin'
# require 'eventmachine'
# require 'rack'
# require 'redis'

require "message_bus/version"
require "message_bus/message"
require "message_bus/reliable_pub_sub"
require "message_bus/client"
require "message_bus/connection_manager"
require "message_bus/message_handler"
require "message_bus/diagnostics"
require "message_bus/rack/middleware"
require "message_bus/rack/diagnostics"

# we still need to take care of the logger
if defined?(::Rails)
  require 'message_bus/rails/railtie'
end

module MessageBus; end
module MessageBus::Implementation

  def cache_assets=(val)
    @cache_assets = val
  end

  def cache_assets
    if defined? @cache_assets
      @cache_assets
    else
      true
    end
  end

  def logger=(logger)
    @logger = logger
  end

  def logger
    return @logger if @logger
    require 'logger'
    @logger = Logger.new(STDOUT)
  end

  def sockets_enabled?
    @sockets_enabled == false ? false : true
  end

  def sockets_enabled=(val)
    @sockets_enabled = val
  end

  def long_polling_enabled?
    @long_polling_enabled == false ? false : true
  end

  def long_polling_enabled=(val)
    @long_polling_enabled = val
  end

  def long_polling_interval=(millisecs)
    @long_polling_interval = millisecs
  end

  def long_polling_interval
    @long_polling_interval || 30 * 1000
  end

  def off
    @off = true
  end

  def on
    @off = false
  end

  # Allow us to inject a redis db
  def redis_config=(config)
    @redis_config = config
  end

  def redis_config
    @redis_config ||= {}
  end

  def site_id_lookup(&blk)
    @site_id_lookup = blk if blk
    @site_id_lookup
  end

  def user_id_lookup(&blk)
    @user_id_lookup = blk if blk
    @user_id_lookup
  end

  def is_admin_lookup(&blk)
    @is_admin_lookup = blk if blk
    @is_admin_lookup
  end

  def on_connect(&blk)
    @on_connect = blk if blk
    @on_connect
  end

  def on_disconnect(&blk)
    @on_disconnect = blk if blk
    @on_disconnect
  end

  def allow_broadcast=(val)
    @allow_broadcast = val
  end

  def allow_broadcast?
    @allow_broadcast ||=
      if defined? ::Rails
        ::Rails.env.test? || ::Rails.env.development?
      else
        false
      end
  end

  def reliable_pub_sub
    @reliable_pub_sub ||= MessageBus::ReliablePubSub.new redis_config
  end

  def enable_diagnostics
    MessageBus::Diagnostics.enable
  end

  def publish(channel, data, opts = nil)
    return if @off

    user_ids = nil
    if opts
      user_ids = opts[:user_ids] if opts
    end

    encoded_data = JSON.dump({
      data: data,
      user_ids: user_ids
    })

    reliable_pub_sub.publish(encode_channel_name(channel), encoded_data)
  end

  def blocking_subscribe(channel=nil, &blk)
    if channel
      reliable_pub_sub.subscribe(encode_channel_name(channel), &blk)
    else
      reliable_pub_sub.global_subscribe(&blk)
    end
  end

  ENCODE_SITE_TOKEN = "$|$"

  # encode channel name to include site
  def encode_channel_name(channel)
    if MessageBus.site_id_lookup
      raise ArgumentError.new channel if channel.include? ENCODE_SITE_TOKEN
      "#{channel}#{ENCODE_SITE_TOKEN}#{MessageBus.site_id_lookup.call}"
    else
      channel
    end
  end

  def decode_channel_name(channel)
    channel.split(ENCODE_SITE_TOKEN)
  end

  def subscribe(channel=nil, &blk)
    subscribe_impl(channel, nil, &blk)
  end

  # subscribe only on current site
  def local_subscribe(channel=nil, &blk)
    site_id = MessageBus.site_id_lookup.call if MessageBus.site_id_lookup
    subscribe_impl(channel, site_id, &blk)
  end

  def backlog(channel=nil, last_id)
    old =
      if channel
        reliable_pub_sub.backlog(encode_channel_name(channel), last_id)
      else
        reliable_pub_sub.global_backlog(encode_channel_name(channel), last_id)
      end

    old.each{ |m|
      decode_message!(m)
    }
    old
  end


  def last_id(channel)
    reliable_pub_sub.last_id(encode_channel_name(channel))
  end

  protected

  def decode_message!(msg)
    channel, site_id = decode_channel_name(msg.channel)
    msg.channel = channel
    msg.site_id = site_id
    parsed = JSON.parse(msg.data)
    msg.data = parsed["data"]
    msg.user_ids = parsed["user_ids"]
  end

  def subscribe_impl(channel, site_id, &blk)
    @subscriptions ||= {}
    @subscriptions[site_id] ||= {}
    @subscriptions[site_id][channel] ||=  []
    @subscriptions[site_id][channel] << blk
    ensure_subscriber_thread
  end

  def ensure_subscriber_thread
    @mutex ||= Mutex.new
    @mutex.synchronize do
      return if @subscriber_thread
      @subscriber_thread = Thread.new do
        reliable_pub_sub.global_subscribe do |msg|
          begin
            decode_message!(msg)

            globals = @subscriptions[nil]
            locals = @subscriptions[msg.site_id] if msg.site_id

            global_globals = globals[nil] if globals
            local_globals = locals[nil] if locals

            globals = globals[msg.channel] if globals
            locals = locals[msg.channel] if locals

            multi_each(globals,locals, global_globals, local_globals) do |c|
              begin
                c.call msg
              rescue => e
                MessageBus.logger.warn "failed to deliver message, skipping #{msg.inspect}\n ex: #{e} backtrace: #{e.backtrace}"
              end
            end

          rescue => e
            MessageBus.logger.warn "failed to process message #{msg.inspect}\n ex: #{e} backtrace: #{e.backtrace}"
          end

        end
      end
    end
  end

  def multi_each(*args,&block)
    args.each do |a|
      a.each(&block) if a
    end
  end

end

module MessageBus
  extend MessageBus::Implementation
end

# allows for multiple buses per app
class MessageBus::Instance
  include MessageBus::Implementation
end
