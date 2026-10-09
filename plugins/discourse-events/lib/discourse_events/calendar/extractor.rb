# frozen_string_literal: true

module DiscourseEvents
  module Calendar
    class Extractor
      DATA_PREFIX = "data-calendar-"

      def self.extract(post)
        cooked = PrettyText.cook(post.raw, topic_id: post.topic_id, user_id: post.user_id)

        Nokogiri
          .HTML(cooked)
          .css("div.calendar")
          .map do |cooked_calendar|
            calendar = {}

            cooked_calendar.attributes.values.each do |attribute|
              if attribute.name.start_with?(DATA_PREFIX)
                calendar[attribute.name[DATA_PREFIX.length..-1]] = CGI.escapeHTML(
                  attribute.value || "",
                )
              end
            end

            calendar
          end
      end

      def self.update(post)
        calendar = extract(post)
        return destroy(post) if calendar.size != 1
        calendar = calendar.first

        post.custom_fields[DiscourseEvents::CALENDAR_CUSTOM_FIELD] = calendar.delete("type") ||
          "dynamic"
        post.save_custom_fields

        Post.where(topic_id: post.topic_id).each { |p| DiscourseEvents::Calendar::Event.update(p) }
      end

      def self.destroy(post)
        return if post.custom_fields[DiscourseEvents::CALENDAR_CUSTOM_FIELD].blank?

        post.custom_fields.delete(DiscourseEvents::CALENDAR_CUSTOM_FIELD)
        post.save_custom_fields

        DiscourseEvents::Calendar::Event.where(topic_id: post.topic_id).destroy_all
      end
    end
  end
end
