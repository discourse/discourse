module Jobs
  class CleanUpSidekiqStatistic < Jobs::Onceoff
    def execute_onceoff(args)
      $redis.without_namespace.del('sidekiq:sidekiq:statistic')
    end
  end
end
