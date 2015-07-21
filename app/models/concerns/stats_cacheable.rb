module StatsCacheable
  extend ActiveSupport::Concern

  module ClassMethods
    def stats_cache_key
      raise 'Stats cache key has not been set.'
    end

    def fetch_stats
      raise 'Not implemented.'
    end

    # Could be configurable, multisite need to support it.
    def recalculate_stats_interval
      30 # minutes
    end

    def fetch_cached_stats
      # The scheduled Stats job is responsible for generating and caching this.
      stats = $redis.get(stats_cache_key)
      stats ? JSON.parse(stats) : nil
    end
  end
end
