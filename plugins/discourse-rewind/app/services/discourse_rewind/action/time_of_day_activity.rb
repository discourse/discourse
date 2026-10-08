# frozen_string_literal: true

module DiscourseRewind
  module Action
    class TimeOfDayActivity < BaseReport
      FakeData = {
        data: {
          activity_by_hour: [
            12,
            8,
            5,
            2,
            1,
            3,
            8,
            15,
            25,
            32,
            28,
            24,
            22,
            20,
            26,
            30,
            28,
            22,
            18,
            16,
            14,
            18,
            22,
            15,
          ],
          most_active_hour: 9,
        },
        identifier: "time-of-day-activity",
      }

      def call
        return FakeData if should_use_fake_data?

        activity_by_hour = get_activity_by_hour
        return if activity_by_hour.sum == 0

        {
          data: {
            activity_by_hour:,
            most_active_hour: activity_by_hour.index(activity_by_hour.max),
          },
          identifier: "time-of-day-activity",
        }
      end

      private

      def get_activity_by_hour
        timezone = ActiveRecord::Base.connection.quote(UserOption.user_tzinfo(user.id).identifier)
        hour =
          Arel.sql(
            "EXTRACT(HOUR FROM created_at AT TIME ZONE 'UTC' AT TIME ZONE #{timezone})::integer",
          )

        models = [Post]
        models << Chat::Message if self.class.plugin_enabled?("chat")
        counts =
          models.map { |model| model.where(user_id: user.id, created_at: date).group(hour).count }

        (0..23).map { |hour_of_day| counts.sum { |count| count.fetch(hour_of_day, 0) } }
      end
    end
  end
end
