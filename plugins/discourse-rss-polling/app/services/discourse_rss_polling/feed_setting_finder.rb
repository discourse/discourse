# frozen_string_literal: true

module DiscourseRssPolling
  class FeedSettingFinder
    def self.by_embed_url(embed_url)
      host = URI.parse(embed_url).host.sub(/^www\./, "")
      feed = RssFeed.where("url LIKE ?", "%#{host}%").first
      return nil if !feed
      FeedSetting.new(
        id: feed.id,
        feed_url: feed.url,
        author_username: feed.author,
        discourse_category_id: feed.category_id,
        discourse_tags: feed.tags.nil? ? nil : feed.tags.split(","),
        feed_category_filter: feed.category_filter,
      )
    end

    def self.all
      new.all
    end

    def initialize
      @condition = Proc.new { |*| true }
    end

    def where(&block)
      @condition = block
      self
    end

    def all
      RssFeed.all.map do |feed|
        FeedSetting.new(
          id: feed.id,
          feed_url: feed.url,
          author_username: feed.author,
          discourse_category_id: feed.category_id,
          discourse_tags: feed.tags.nil? ? nil : feed.tags.split(","),
          feed_category_filter: feed.category_filter,
        )
      end
    end

    def take
      all&.first
    end
  end
end
