# frozen_string_literal: true

module DiscoursePostEvent
  class EventSummarySerializer < ApplicationSerializer
    attributes :id
    attributes :starts_at
    attributes :ends_at
    attributes :show_local_time
    attributes :timezone
    attributes :post
    attributes :name
    attributes :category_id
    attributes :rrule

    # lightweight post object containing
    # only needed info for client
    def post
      post_hash = {
        id: object.post.id,
        post_number: object.post.post_number,
        url: object.post.url,
        topic: {
          id: object.post.topic.id,
          title: object.post.topic.title,
        },
      }

      if post_hash[:topic][:title].match?(/:[\w\-+]+:/)
        post_hash[:topic][:title] = Emoji.gsub_emoji_to_unicode(post_hash[:topic][:title])
      end

      if JSON.parse(SiteSetting.map_events_to_color).size > 0
        post_hash[:topic][:category_slug] = object.post.topic&.category&.slug
        post_hash[:topic][:tags] = object.post.topic.tags&.map(&:name)
      end

      post_hash
    end

    def category_id
      object.post.topic.category_id
    end

    def include_rrule?
      object.recurring?
    end

    def rrule
      RRuleConfigurator.rule(
        recurrence: object.recurrence,
        starts_at: object.starts_at.in_time_zone(object.timezone),
        recurrence_until: object.recurrence_until&.in_time_zone(object.timezone),
      )
    end
  end
end
