# frozen_string_literal: true

module Jobs
  class CleanUpSidekiqStatistic < OnceoffBase
    def execute_onceoff(args)
      $redis.without_namespace.del('sidekiq:sidekiq:statistic')
    end
  end
end
