# frozen_string_literal: true

module DiscourseRssPolling
  module FeedSetting
    class Update
      include Service::Base

      params do
        attribute :id, :integer
        attribute :feed_url, :string
        attribute :author_username, :string
        attribute :discourse_category_id, :integer
        attribute :discourse_tags, :array
        attribute :feed_category_filter, :string

        validates :feed_url, presence: true
        validates :author_username, presence: true

        before_validation :normalize_tags

        def normalize_tags
          return if discourse_tags.blank?

          self.discourse_tags =
            discourse_tags.map { |tag| tag.is_a?(String) ? tag : tag["name"] || tag[:name] }.compact
        end

        def tag_names
          discourse_tags&.join(",").presence
        end
      end

      model :user
      model :rss_feed, :upsert_rss_feed

      private

      def fetch_user(params:)
        ::User.find_by_username(params.author_username)
      end

      def upsert_rss_feed(params:, user:)
        feed = RssFeed.find_or_initialize_by(id: params.id)
        feed.assign_attributes(
          url: params.feed_url,
          user: user,
          category_id: params.discourse_category_id,
          tags: params.tag_names,
          category_filter: params.feed_category_filter,
        )
        feed.save!
        feed
      end
    end
  end
end
