# frozen_string_literal: true

# Time of day activity analysis
# Shows when a user is most active (considering their timezone)
# Determines if they are a night owl or early bird
module DiscourseRewind
  module Action
    class TimeOfDayActivity < BaseReport
      EARLY_BIRD_THRESHOLD = 6..9
      NIGHT_OWL_THRESHOLD_PM = 22..23
      NIGHT_OWL_THRESHOLD_AM = 0..2

      FakeData = {
        data: {
          activity_by_hour: {
            0 => 12,
            1 => 8,
            2 => 5,
            3 => 2,
            4 => 1,
            5 => 3,
            6 => 8,
            7 => 15,
            8 => 25,
            9 => 32,
            10 => 28,
            11 => 24,
            12 => 22,
            13 => 20,
            14 => 26,
            15 => 30,
            16 => 28,
            17 => 22,
            18 => 18,
            19 => 16,
            20 => 14,
            21 => 18,
            22 => 22,
            23 => 15,
          },
          most_active_hour: 9,
          personality: {
            type: "early_bird",
            percentage: 28.5,
          },
          total_activities: 414,
        },
        identifier: "time-of-day-activity",
      }

      def call
        return FakeData if should_use_fake_data?
        # Get activity by hour of day (in user's timezone)
        activity_by_hour = get_activity_by_hour

        return if activity_by_hour.empty?

        total_activities = activity_by_hour.values.sum
        most_active_hour = activity_by_hour.max_by { |_, count| count }&.first
        personality = determine_personality(activity_by_hour, total_activities)

        {
          data: {
            activity_by_hour: activity_by_hour,
            most_active_hour: most_active_hour,
            personality: personality,
            total_activities: total_activities,
          },
          identifier: "time-of-day-activity",
        }
      end

      private

      def get_activity_by_hour
        # Get user timezone offset
        user_timezone = user.user_option&.timezone || "UTC"
        quoted_timezone = ActiveRecord::Base.connection.quote(user_timezone)
        hour_extract_sql =
          Arel.sql(
            "EXTRACT(HOUR FROM created_at AT TIME ZONE 'UTC' AT TIME ZONE #{quoted_timezone})::integer",
          )

        # Initialize hash with all hours
        activity = (0..23).to_h { |hour| [hour, 0] }

        # Posts created
        post_hours =
          Post
            .where(user_id: user.id)
            .where(created_at: date)
            .where(deleted_at: nil)
            .pluck(hour_extract_sql)
            .tally

        # User visits (page views)
        visit_hours =
          UserHistory
            .where(acting_user_id: user.id)
            .where(created_at: date)
            .where(action: UserHistory.actions[:page_view])
            .pluck(hour_extract_sql)
            .tally

        # Chat messages if chat is enabled
        if Discourse.plugins_by_name["chat"]&.enabled?
          chat_hours =
            Chat::Message
              .where(user_id: user.id)
              .where(created_at: date)
              .where(deleted_at: nil)
              .pluck(hour_extract_sql)
              .tally

          chat_hours.each { |hour, count| activity[hour] += count }
        end

        post_hours.each { |hour, count| activity[hour] += count }
        visit_hours.each { |hour, count| activity[hour] += count }

        activity
      end

      def determine_personality(activity_by_hour, total_activities)
        return nil if total_activities == 0

        early_bird_activity = EARLY_BIRD_THRESHOLD.sum { |hour| activity_by_hour[hour] || 0 }
        night_owl_activity =
          NIGHT_OWL_THRESHOLD_PM.sum { |hour| activity_by_hour[hour] || 0 } +
            NIGHT_OWL_THRESHOLD_AM.sum { |hour| activity_by_hour[hour] || 0 }

        early_bird_percentage = (early_bird_activity.to_f / total_activities * 100).round(1)
        night_owl_percentage = (night_owl_activity.to_f / total_activities * 100).round(1)

        if early_bird_percentage > 20
          { type: "early_bird", percentage: early_bird_percentage }
        elsif night_owl_percentage > 20
          { type: "night_owl", percentage: night_owl_percentage }
        else
          { type: "balanced", percentage: 0 }
        end
      end
    end
  end
end
