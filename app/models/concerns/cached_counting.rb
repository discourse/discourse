module CachedCounting
  extend ActiveSupport::Concern

  included do
    class << self
      attr_accessor :autoflush, :autoflush_seconds, :last_flush
    end

    # auto flush if backlog is larger than this
    self.autoflush = 2000

    # auto flush if older than this
    self.autoflush_seconds = 5.minutes

    self.last_flush = Time.now.utc
  end

  class_methods do
    def perform_increment!(key, opts = nil)
      val = $redis.incr(key).to_i

      # readonly mode it is going to be 0, skip
      return if val == 0

      # 3.days, see: https://github.com/rails/rails/issues/21296
      $redis.expire(key, 259200)

      autoflush = (opts && opts[:autoflush]) || self.autoflush
      if autoflush > 0 && val >= autoflush
        write_cache!
        return
      end

      if (Time.now.utc - last_flush).to_i > autoflush_seconds
        write_cache!
      end
    end

    def write_cache!(date = nil)
      raise NotImplementedError
    end

    GET_AND_RESET = <<~LUA
      local val = redis.call('get', KEYS[1])
      redis.call('set', KEYS[1], '0')
      return val
    LUA

    # this may seem a bit fancy but in so it allows
    # for concurrent calls without double counting
    def get_and_reset(key)
      namespaced_key = $redis.namespace_key(key)
      val = $redis.without_namespace.eval(GET_AND_RESET, keys: [namespaced_key]).to_i
      $redis.expire(key, 259200) # SET removes expiry, so set it again
      val
    end

    def request_id(query_params, retries = 0)
      id = where(query_params).pluck(:id).first
      id ||= create!(query_params.merge(count: 0)).id
    rescue # primary key violation
      if retries == 0
        request_id(query_params, 1)
      else
        raise
      end
    end
  end
end
