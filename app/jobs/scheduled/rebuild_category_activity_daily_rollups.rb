# frozen_string_literal: true

module Jobs
  class RebuildCategoryActivityDailyRollups < ::Jobs::Scheduled
    daily at: 5.hours

    cluster_concurrency 1

    def execute(_args = {})
      CategoryActivityDailyRollup.rebuild!
    end
  end
end
