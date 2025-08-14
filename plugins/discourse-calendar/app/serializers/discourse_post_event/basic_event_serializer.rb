# frozen_string_literal: true

module DiscoursePostEvent
  class BasicEventSerializer < ApplicationSerializer
    attributes :id
    attributes :category_id
    attributes :name
    attributes :recurrence
    attributes :recurrence_until
    attributes :starts_at
    attributes :ends_at
    attributes :rrule
    attributes :show_local_time
    attributes :timezone
    attributes :post

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
      RRuleGenerator.generate_string(
        starts_at: object.original_starts_at.in_time_zone(object.timezone),
        timezone: object.timezone,
        recurrence: object.recurrence,
        recurrence_until: object.recurrence_until&.in_time_zone(object.timezone),
        dtstart: object.original_starts_at.in_time_zone(object.timezone),
      )
    end

    def starts_at
      # For recurring events, use the original start time to be consistent with rrule
      # For non-recurring events, use the calculated start time
      if object.recurring?
        object.original_starts_at
      else
        object.starts_at
      end
    end

    def ends_at
      if object.ends_at
        object.ends_at
      else
        # For recurring events, use original_starts_at as the base for calculation
        base_starts_at = object.recurring? ? object.original_starts_at : object.starts_at
        base_starts_at + 1.hour
      end
    end
  end
end
