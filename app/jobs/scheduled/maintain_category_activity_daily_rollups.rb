# frozen_string_literal: true

module Jobs
  class MaintainCategoryActivityDailyRollups < ::Jobs::Scheduled
    every 3.hours

    cluster_concurrency 1

    REFRESH_WINDOW_DAYS = 2

    def execute(_args = {})
      return CategoryActivityDailyRollup.rebuild! if CategoryActivityDailyRollup.none?

      CategoryActivityDailyRollup.aggregate(
        start_date: REFRESH_WINDOW_DAYS.days.ago.to_date,
        end_date: Time.zone.today,
      )
    end
  end
end
