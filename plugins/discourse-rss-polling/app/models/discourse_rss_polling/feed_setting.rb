# frozen_string_literal: true

module DiscourseRssPolling
  class FeedSetting
    include ActiveModel::Serialization

    attr_accessor(
      :id,
      :feed_url,
      :author_username,
      :discourse_category_id,
      :discourse_tags,
      :feed_category_filter,
    )

    def initialize(
      id: nil,
      feed_url:,
      author_username:,
      discourse_category_id:,
      discourse_tags:,
      feed_category_filter:
    )
      @id = id
      @feed_url = feed_url
      @author_username = author_username
      @discourse_category_id = discourse_category_id
      @discourse_tags = discourse_tags
      @feed_category_filter = feed_category_filter
    end

    def poll(inline: false)
      if inline
        Jobs::DiscourseRssPolling::PollFeed.new.execute(
          feed_url: feed_url,
          author_username: author_username,
          discourse_category_id: discourse_category_id,
          discourse_tags: discourse_tags,
          feed_category_filter: feed_category_filter,
        )
      else
        Jobs.enqueue(
          "DiscourseRssPolling::PollFeed",
          feed_url: feed_url,
          author_username: author_username,
          discourse_category_id: discourse_category_id,
          discourse_tags: discourse_tags,
          feed_category_filter: feed_category_filter,
        )
      end
    end
  end
end
