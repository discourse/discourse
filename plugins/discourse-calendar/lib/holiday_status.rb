# frozen_string_literal: true

module DiscourseCalendar
  class HolidayStatus
    def self.set!(user, ends_at)
      status = user.user_status
      if status.blank? || status.expired? ||
           (is_holiday_status?(status) && status.ends_at != ends_at)
        user.set_status!(
          I18n.t("discourse_calendar.holiday_status.description"),
          emoji_name,
          ends_at,
        )
      end
    end

    def self.clear!(user)
      user.clear_status! if user&.user_status && is_holiday_status?(user.user_status)
    end

    private

    def self.is_holiday_status?(status)
      status.emoji == emoji_name &&
        status.description == I18n.t("discourse_calendar.holiday_status.description")
    end

    def self.emoji_name
      emoji = SiteSetting.holiday_status_emoji
      emoji.blank? ? "date" : emoji
    end
  end
end
