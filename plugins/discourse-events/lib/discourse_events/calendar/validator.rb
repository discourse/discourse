# frozen_string_literal: true

module DiscourseEvents
  module Calendar
    class Validator
      def initialize(post)
        @post = post
      end

      def validate_calendar
        extracted_calendars = DiscourseEvents::Calendar::Extractor.extract(@post)

        return false if extracted_calendars.count == 0

        if extracted_calendars.count > 1
          @post.errors.add(:base, I18n.t("discourse_calendar.more_than_one_calendar"))
          return false
        end

        if !@post.is_first_post?
          @post.errors.add(:base, I18n.t("discourse_calendar.calendar_must_be_in_first_post"))
          return false
        end

        true
      end
    end
  end
end
