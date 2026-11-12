# frozen_string_literal: true

module DiscourseRssPolling
  class FeedSettingSerializer < ApplicationSerializer
    attributes :id,
               :feed_url,
               :redacted_feed_url,
               :discourse_category_id,
               :discourse_tags,
               :feed_category_filter,
               :enabled

    has_one :author, serializer: BasicUserSerializer, embed: :objects

    def feed_url
      object.url
    end

    def include_feed_url?
      !!@options[:include_url]
    end

    def redacted_feed_url
      FeedUrl.redact(object.url)
    end

    def author
      object.user
    end

    def discourse_category_id
      object.category_id
    end

    def discourse_tags
      object.tags&.split(",")
    end

    def feed_category_filter
      object.category_filter
    end
  end
end
