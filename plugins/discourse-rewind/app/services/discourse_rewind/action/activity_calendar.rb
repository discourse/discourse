# frozen_string_literal: true

# For a GitHub like calendar
# https://docs.github.com/assets/cb-35216/mw-1440/images/help/profile/contributions-graph.webp
module DiscourseRewind
  module Action
    class ActivityCalendar < BaseReport
      FakeData = {
        data:
          (Date.new(2024, 1, 1)..Date.new(2024, 12, 31)).map do |date|
            { date:, post_count: rand(0..20), visited: false }
          end,
        identifier: "activity-calendar",
      }

      def call
        return FakeData if should_use_fake_data?

        calendar =
          Post
            .unscoped
            .joins(<<~SQL)
            RIGHT JOIN
              generate_series('#{date.first}', '#{date.last}', '1 day'::interval) ON
              posts.created_at::date = generate_series::date AND
              posts.user_id = #{user.id} AND
              posts.deleted_at IS NULL
          SQL
            .joins(
              "LEFT JOIN user_visits ON generate_series::date = visited_at AND user_visits.user_id = #{user.id}",
            )
            .select(
              "generate_series::date as date, count(posts.id) as post_count, COUNT(visited_at) > 0 as visited",
            )
            .group("generate_series, user_visits.id")
            .order("generate_series")
            .map { |row| { date: row.date, post_count: row.post_count, visited: row.visited } }

        { data: calendar, identifier: "activity-calendar" }
      end
    end
  end
end
