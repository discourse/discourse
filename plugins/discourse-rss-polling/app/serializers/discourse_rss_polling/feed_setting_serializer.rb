# frozen_string_literal: true

module DiscourseRssPolling
  class FeedSettingSerializer < ApplicationSerializer
    attributes :id,
               :feed_url,
               :user_id,
               :author_username,
               :discourse_category_id,
               :discourse_tags,
               :feed_category_filter

    def feed_url
      object.url
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
