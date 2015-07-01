module Jobs
  class DashboardStats < Jobs::Scheduled
    every 30.minutes

    def execute(args)
      stats = AdminDashboardData.fetch_stats.as_json

      # Add some extra time to the expiry so that the next job run has plenty of time to
      # finish before previous cached value expires.
      $redis.setex AdminDashboardData.stats_cache_key, (AdminDashboardData.recalculate_interval + 5).minutes, stats.to_json

      stats
    end

  end
end
