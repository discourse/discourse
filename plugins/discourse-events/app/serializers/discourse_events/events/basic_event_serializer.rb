# frozen_string_literal: true

module DiscourseEvents
  module Events
    class BasicEventSerializer < ApplicationSerializer
      attributes :id,
                 :category_id,
                 :name,
                 :recurrence,
                 :recurrence_until,
                 :starts_at,
                 :ends_at,
                 :rrule,
                 :show_local_time,
                 :timezone,
                 :post,
                 :duration,
                 :occurrences,
                 :all_day,
                 :custom_fields

      def category_id
        object.post&.topic&.category_id
      end

      def post
        return nil if object.post.blank?

        {
          id: object.post.id,
          post_number: object.post.post_number,
          url: object.post.url,
          category_slug:
            (
              if object.post.topic && object.post.topic.category
                object.post.topic.category.slug_for_url
              else
                ""
              end
            ),
          topic:
            DiscourseEvents::Events::EventTopicSerializer.new(
              object.post.topic,
              scope:,
              root: false,
            ).as_json,
        }
      end

      def include_rrule?
        object.recurring?
      end

      def rrule
        return nil unless include_rrule?

        timezone_starts_at = object.original_starts_at.in_time_zone(object.timezone)
        timezone_recurrence_until = object.recurrence_until&.in_time_zone(object.timezone)

        DiscourseEvents::Events::RRuleGenerator.generate_string(
          starts_at: timezone_starts_at,
          recurrence: object.recurrence,
          recurrence_until: timezone_recurrence_until,
          dtstart: timezone_starts_at,
          show_local_time: object.show_local_time,
        )
      end

      def starts_at
        return object.starts_at.utc.strftime("%Y-%m-%d") if object.all_day

        format_time(object.starts_at)
      end

      def ends_at
        return object.ends_at&.utc&.strftime("%Y-%m-%d") if object.all_day

        format_time(object.ends_at || object.starts_at + 1.hour)
      end

      def format_time(time)
        time = time.in_time_zone(object.timezone)
        object.show_local_time ? time.strftime("%Y-%m-%dT%H:%M:%S") : time.iso8601(3)
      end

      def duration
        object.duration
      end

      def include_duration?
        object.duration.present?
      end

      def occurrences
        @options[:occurrences]
      end

      def include_occurrences?
        @options[:include_occurrences] != false
      end
    end
  end
end
