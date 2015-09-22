# Like a hash, just does its best to stay in sync across the farm
# On boot all instances are blank, but they populate as various processes
# fill it up

require 'weakref'

class DistributedCache
  @subscribers = []
  @subscribed = false
  @lock = Mutex.new

  attr_reader :key

  def self.subscribers
    @subscribers
  end

  def self.process_message(message)
    i = @subscribers.length-1

    payload = message.data

    while i >= 0
      begin
        current = @subscribers[i]

        next if payload["origin"] == current.identity
        next if current.key != payload["hash_key"]
        next if payload["discourse_version"] != Discourse.git_version

        hash = current.hash(message.site_id)

        case payload["op"]
          when "set" then hash[payload["key"]] = payload["marshalled"] ?  Marshal.load(payload["value"]) : payload["value"]
          when "delete" then hash.delete(payload["key"])
          when "clear"  then hash.clear
        end

      rescue WeakRef::RefError
        @subscribers.delete_at(i)
      ensure
        i -= 1
      end
    end
  end

  def self.channel_name
    "/distributed_hash".freeze
  end

  def self.ensure_subscribe!
    return if @subscribed
    @lock.synchronize do
      return if @subscribed
      MessageBus.subscribe(channel_name) do |message|
        @lock.synchronize do
          process_message(message)
        end
      end
      @subscribed = true
    end
  end

  def self.publish(hash, message)
    message[:origin] = hash.identity
    message[:hash_key] = hash.key
    message[:discourse_version] = Discourse.git_version
    MessageBus.publish(channel_name, message, { user_ids: [-1] })
  end

  def self.set(hash, key, value)
    # special support for set
    marshal = Set === value
    value = Marshal.dump(value) if marshal
    publish(hash, { op: :set, key: key, value: value, marshalled: marshal })
  end

  def self.delete(hash, key)
    publish(hash, { op: :delete, key: key })
  end

  def self.clear(hash)
    publish(hash, { op: :clear })
  end

  def self.register(hash)
    @lock.synchronize do
      @subscribers << WeakRef.new(hash)
    end
  end

  def initialize(key)
    DistributedCache.ensure_subscribe!
    DistributedCache.register(self)

    @key = key
    @data = {}
  end

  def identity
    # fork resilient / multi machine identity
    (@seed_id ||= SecureRandom.hex) + "#{Process.pid}"
  end

  def []=(k,v)
    k = k.to_s if Symbol === k
    DistributedCache.set(self, k, v)
    hash[k] = v
  end

  def [](k)
    k = k.to_s if Symbol === k
    hash[k]
  end

  def delete(k)
    k = k.to_s if Symbol === k
    DistributedCache.delete(self, k)
    hash.delete(k)
  end

  def clear
    DistributedCache.clear(self)
    hash.clear
  end

  def hash(db = nil)
    db ||= RailsMultisite::ConnectionManagement.current_db
    @data[db] ||= ThreadSafe::Hash.new
  end

end
