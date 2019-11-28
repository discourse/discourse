# frozen_string_literal: true

module Jobs
  class CleanUpSidekiqStatistic < ::Jobs::Onceoff
    def execute_onceoff(args)
      Discourse.redis.without_namespace.del('sidekiq:sidekiq:statistic')
    end
  end
end
