# frozen_string_literal: true

# This is a replacement for DistributedCache which is bounded and respects
# clears during deploys
class LiveCache
  class Manager
    CHANNEL_NAME ||= "/live_cache"

    def initialize(message_bus: MessageBus)
      @message_bus = message_bus
      @subscription = Concurrent::Promises.delay(&method(:subscribe))
      @mutex = Mutex.new
      @caches = Hash.new { |h, k| h[k] = WeakList.new }
    end

    def register(hash_key, cache)
      @mutex.synchronize { @caches[hash_key] << cache }

      ensure_subscribed!
    end

    def publish(message)
      @message_bus.publish(CHANNEL_NAME, message)
    end

    private

    def process_message(message)
      @mutex.synchronize do
        @caches[message.data["hash_key"]].each { |cache| cache.process_message(message) }
      end
    end

    def subscribe
      @message_bus.subscribe(CHANNEL_NAME) { |message| process_message(message) }
    end

    def ensure_subscribed!
      @subscription.wait!
    end
  end

  class << self
    attr_accessor :default_manager
  end

  self.default_manager = Manager.new

  attr_reader :identity

  def initialize(
    hash_key,
    max_size_per_site:,
    live_cache_multiplier: GlobalSetting.live_cache_multiplier,
    manager: LiveCache.default_manager,
    namespace: true
  )
    @manager = manager
    @hash_key = hash_key
    @manager.register(hash_key, self)
    @identity = SecureRandom.hex
    @namespace = namespace

    @data =
      SiteCache.new(
        max_global_size: live_cache_multiplier * max_size_per_site,
        max_size_per_site: max_size_per_site,
      )
  end

  def getset(key, &blk)
    raise TypeError if !Rails.env.production? && !k.is_a?(String)

    @data.getset(get_site_id, key, &blk)
  end

  alias_method :defer_get_set, :getset

  def getset_bulk(ks, key_blk, &blk)
    @data.getset_bulk(get_site_id, ks, key_blk, &blk)
  end

  alias_method :defer_get_set_bulk, :getset_bulk

  def clear(after_commit: true)
    if after_commit
      DB.after_commit { clear_now }
    else
      clear_now
    end
  end

  def delete(key)
    @data.delete(get_site_id, key)

    Scheduler::Defer.later("#{@hash_key}_clear_site") do
      @manager.publish(
        { "hash_key" => @hash_key, "identity" => identity, "op" => "delete", "key" => key },
      )
    end
  end

  def clear_regex(regex)
    @data.clear_site_regex(get_site_id, regex)

    Scheduler::Defer.later("#{@hash_key}_clear_site") do
      @manager.publish(
        {
          "hash_key" => @hash_key,
          "identity" => identity,
          "op" => "clear_site_regex",
          "regex" => regex.to_s,
        },
      )
    end
  end

  def clear_all
    @data.clear

    Scheduler::Defer.later("#{@hash_key}_clear_all") do
      @manager.publish({ "hash_key" => @hash_key, "identity" => identity, "op" => "clear_all" })
    end
  end

  def keys
    @data.site_keys(get_site_id)
  end

  def process_message(message)
    return if message.data["identity"] == identity

    case message.data["op"]
    when "clear_all"
      @data.clear
    when "clear_site"
      @data.clear_site(message.site_id)
    when "clear_site_regex"
      @data.clear_site_regex(message.site_id, Regexp.new(message.data["regex"]))
    when "delete"
      @data.delete(message.site_id, message.data["key"])
    end
  end

  private

  def clear_now
    @data.clear_site(get_site_id)

    Scheduler::Defer.later("#{@hash_key}_clear_site") do
      @manager.publish({ "hash_key" => @hash_key, "identity" => identity, "op" => "clear_site" })
    end
  end

  def get_site_id
    RailsMultisite::ConnectionManagement.current_db if @namespace
  end
end
