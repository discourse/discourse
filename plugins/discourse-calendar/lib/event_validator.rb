# frozen_string_literal: true

module DiscourseCalendar
  class EventValidator
    def initialize(post)
      @post = post
      @first_post = post.topic.first_post
    end

    def validate_event
      dates_count = count_dates(@post)
      calendar_type = @first_post.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD]

      if calendar_type == "dynamic" && dates_count > 2
        @post.errors.add(:base, I18n.t("discourse_calendar.more_than_two_dates"))
        return false
      end

      return false if calendar_type == "static" && dates_count > 0

      dates_count > 0
    end

    private

    def count_dates(post)
      cooked = PrettyText.cook(post.raw, topic_id: post.topic_id, user_id: post.user_id)
      Nokogiri.HTML(cooked).css("span.discourse-local-date").count
    end
  end
end
