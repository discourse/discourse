# frozen_string_literal: true

module DiscourseEvents
  module Holidays
    class Status
      class << self
        def set!(user, ends_at)
          status = user.user_status
          if status.blank? || status.expired? ||
               (is_holiday_status?(status) && status.ends_at != ends_at)
            user.set_status!(
              I18n.t("discourse_events.holiday_status.description"),
              emoji_name,
              ends_at,
            )
          end
        end

        def clear!(user)
          user.clear_status! if user&.user_status && is_holiday_status?(user.user_status)
        end

        public

        def is_holiday_status?(status)
          status.emoji == emoji_name &&
            status.description == I18n.t("discourse_events.holiday_status.description")
        end

        def emoji_name
          SiteSetting.holiday_status_emoji.presence || "date"
        end
      end

      private
    end
  end
end
