module Jobs
  class DashboardStats < Jobs::Scheduled
    include Jobs::Stats

    every 30.minutes

    def execute(args)
      stats = AdminDashboardData.fetch_stats
      set_cache(AdminDashboardData, stats)
      stats
    end
  end
end
