# frozen_string_literal: true

# Like a hash, just does its best to stay in sync across the farm
# On boot all instances are blank, but they populate as various processes
# fill it up

require 'weakref'
require 'base64'

class DistributedCache

  class Manager

    def initialize(message_bus = nil)
      @subscribers = []
      @subscribed = false
      @lock = Mutex.new
      @message_bus = message_bus || MessageBus
    end

    def subscribers
      @subscribers
    end

    def process_message(message)
      i = @subscribers.length - 1

      payload = message.data

      while i >= 0
        begin
          current = @subscribers[i]

          next if payload["origin"] == current.identity
          next if current.key != payload["hash_key"]
          next if payload["discourse_version"] != Discourse.git_version

          hash = current.hash(message.site_id)

          case payload["op"]
          when "set" then hash[payload["key"]] = payload["marshalled"] ? Marshal.load(Base64.decode64(payload["value"])) : payload["value"]
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

    def channel_name
      "/distributed_hash".freeze
    end

    def ensure_subscribe!
      return if @subscribed
      @lock.synchronize do
        return if @subscribed
        @message_bus.subscribe(channel_name) do |message|
          @lock.synchronize do
            process_message(message)
          end
        end
        @subscribed = true
      end
    end

    def publish(hash, message)
      message[:origin] = hash.identity
      message[:hash_key] = hash.key
      message[:discourse_version] = Discourse.git_version
      @message_bus.publish(channel_name, message, user_ids: [-1])
    end

    def set(hash, key, value)
      # special support for set
      marshal = (Set === value || Hash === value)
      value = Base64.encode64(Marshal.dump(value)) if marshal
      publish(hash, op: :set, key: key, value: value, marshalled: marshal)
    end

    def delete(hash, key)
      publish(hash, op: :delete, key: key)
    end

    def clear(hash)
      publish(hash, op: :clear)
    end

    def register(hash)
      @lock.synchronize do
        @subscribers << WeakRef.new(hash)
      end
    end
  end

  @default_manager = Manager.new

  def self.default_manager
    @default_manager
  end

  attr_reader :key

  def initialize(key, manager: nil, namespace: true)
    @key = key
    @data = {}
    @manager = manager || DistributedCache.default_manager
    @namespace = namespace

    @manager.ensure_subscribe!
    @manager.register(self)
  end

  def identity
    # fork resilient / multi machine identity
    (@seed_id ||= SecureRandom.hex) + "#{Process.pid}"
  end

  def []=(k, v)
    k = k.to_s if Symbol === k
    @manager.set(self, k, v)
    hash[k] = v
  end

  def [](k)
    k = k.to_s if Symbol === k
    hash[k]
  end

  def delete(k)
    k = k.to_s if Symbol === k
    @manager.delete(self, k)
    hash.delete(k)
  end

  def clear
    @manager.clear(self)
    hash.clear
  end

  def hash(db = nil)
    db ||= begin
      if @namespace
        RailsMultisite::ConnectionManagement.current_db
      else
        RailsMultisite::ConnectionManagement::DEFAULT
      end
    end

    @data[db] ||= ThreadSafe::Hash.new
  end

end
