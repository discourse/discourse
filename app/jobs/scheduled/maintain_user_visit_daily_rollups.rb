# frozen_string_literal: true

module Jobs
  class MaintainUserVisitDailyRollups < ::Jobs::Scheduled
    every 3.hours

    cluster_concurrency 1

    def execute(_args = {})
      initial_aggregation = UserVisitDailyRollup.none?
      start_date, end_date = aggregation_window(initial_aggregation: initial_aggregation)
      return if start_date.nil?

      UserVisitDailyRollup.aggregate(start_date: start_date, end_date: end_date)
    end

    private

    def aggregation_window(initial_aggregation:)
      end_date = Time.zone.today
      return UserVisit.minimum(:visited_at)&.to_date, end_date if initial_aggregation

      start_date = 1.day.ago.to_date
      latest_rollup_date = UserVisitDailyRollup.maximum(:date)
      latest_visit_date = UserVisit.maximum(:visited_at)

      if latest_visit_date && latest_visit_date > latest_rollup_date
        start_date = [start_date, latest_rollup_date + 1.day].min
      end

      [start_date, end_date]
    end
  end
end
