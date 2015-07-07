module Jobs
  module Stats
    def set_cache(klass, stats)
      # Add some extra time to the expiry so that the next job run has plenty of time to
      # finish before previous cached value expires.
      $redis.setex klass.stats_cache_key, (klass.recalculate_stats_interval + 5).minutes, stats.to_json
    end
  end
end
