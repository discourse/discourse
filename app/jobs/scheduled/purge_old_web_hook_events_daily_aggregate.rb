# frozen_string_literal: true

module Jobs
  class PurgeOldWebHookEventsDailyAggregate < ::Jobs::Scheduled
    every 1.day

    def execute(_)
      WebHookEventsDailyAggregate.purge_old
    end
  end
end
