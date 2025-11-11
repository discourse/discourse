# frozen_string_literal: true

module DiscourseAi
  class MultisiteHash
    def initialize(id)
      @hash = Hash.new { |h, k| h[k] = {} }
      @id = id

      MessageBus.subscribe(channel_name) { |message| @hash[message.data] = {} }
    end

    def channel_name
      "/multisite-hash-#{@id}"
    end

    def current_db
      RailsMultisite::ConnectionManagement.current_db
    end

    def fetch(key)
      @hash[current_db][key] ||= yield
    end

    def [](key)
      @hash.dig(current_db, key)
    end

    def []=(key, val)
      @hash[current_db][key] = val
    end

    def flush!
      @hash[current_db] = {}
      MessageBus.publish(channel_name, current_db)
    end

    # TODO implement a GC so we don't retain too much memory
  end
end
