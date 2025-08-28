# frozen_string_literal: true

module DiscoursePostEvent
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
               :duration

    def category_id
      object.post.topic.category_id
    end

    def post
      {
        id: object.post.id,
        post_number: object.post.post_number,
        url: object.post.url,
        topic: {
          id: object.post.topic.id,
          title: object.post.topic.title,
        },
      }
    end

    def include_rrule?
      object.recurring?
    end

    def rrule
      return nil unless include_rrule?

      timezone_starts_at = object.original_starts_at.in_time_zone(object.timezone)
      timezone_recurrence_until = object.recurrence_until&.in_time_zone(object.timezone)

      RRuleGenerator.generate_string(
        starts_at: timezone_starts_at,
        timezone: object.rrule_timezone,
        recurrence: object.recurrence,
        recurrence_until: timezone_recurrence_until,
        dtstart: timezone_starts_at,
        show_local_time: object.show_local_time,
      )
    end

    def starts_at
      if object.show_local_time
        timezone_time = object.original_starts_at&.in_time_zone(object.timezone)
        timezone_time&.strftime("%Y-%m-%dT%H:%M:%S")
      else
        if object.recurring?
          object.original_starts_at&.in_time_zone(object.timezone)
        else
          object.starts_at&.in_time_zone(object.timezone)
        end
      end
    end

    def ends_at
      if object.show_local_time
        ends_at =
          object.original_ends_at ||
            (object.original_starts_at && object.original_starts_at + 1.hour)
        timezone_ends_at = ends_at&.in_time_zone(object.timezone)
        timezone_ends_at&.strftime("%Y-%m-%dT%H:%M:%S")
      else
        if object.recurring?
          object.original_ends_at&.in_time_zone(object.timezone) ||
            (
              object.original_starts_at &&
                object.original_starts_at.in_time_zone(object.timezone) + 1.hour
            )
        else
          if object.ends_at
            object.ends_at&.in_time_zone(object.timezone)
          else
            base_starts_at = object.starts_at&.in_time_zone(object.timezone)
            base_starts_at ? (base_starts_at + 1.hour) : nil
          end
        end
      end
    end

    def duration
      object.duration
    end

    def include_duration?
      object.duration.present?
    end
  end
end
