# frozen_string_literal: true

module Reports::NewContributors
  extend ActiveSupport::Concern

  class_methods do
    def report_new_contributors(report)
      report.data = []

      data_start = report.facets.include?(:prev_period) ? report.prev_start_date : report.start_date
      data = User.real.count_by_first_post(data_start, report.end_date)

      if report.facets.include?(:prev30Days)
        prev30DaysData =
          User.real.count_by_first_post(report.start_date - 30.days, report.start_date)
        report.prev30Days = prev30DaysData.sum { |k, v| v }
      end

      report.total = User.real.count_by_first_post if report.facets.include?(:total)

      if report.facets.include?(:prev_period)
        data, prev_period_data = split_date_counts(data, report.start_date)
        report.prev_period = prev_period_data.sum { |_date, count| count }
      end

      data.each { |key, value| report.data << { x: key, y: value } }

      return if report.guardian.blank?

      users =
        User
          .real
          .preload(:user_stat)
          .with_first_post_created_between(report.start_date, report.end_date)
          .order("user_stats.first_post_created_at DESC")

      report.related_items_totals = { users: users.count }
      users = users.limit(report.limit || Report::RELATED_ITEMS_LIMIT)

      report.related_items = {
        users:
          users.map do |user|
            {
              user: BasicUserSerializer.new(user, scope: report.guardian, root: false).as_json,
              timestamp: user.user_stat.first_post_created_at.iso8601,
            }
          end,
      }
    end
  end
end
