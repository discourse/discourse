# frozen_string_literal: true

module DiscourseRssPolling
  class RssFeed
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
        validate :feed_url_is_http
        validate :satisfies_required_tag_groups

        before_validation :normalize_feed_url
        before_validation :normalize_tags

        def feed_url_is_http
          return if feed_url.blank? || DiscourseRssPolling::FeedUrl.http?(feed_url)

          errors.add(:base, I18n.t("rss_polling.errors.feed_url_must_be_http"))
        end

        def satisfies_required_tag_groups
          return if discourse_category_id.blank?

          category = ::Category.find_by(id: discourse_category_id)
          return if category.nil?

          feed_tags = Array(discourse_tags)

          DiscourseRssPolling::RequiredTagGroups
            .for_category(category)
            .each do |group|
              next if (feed_tags & group[:tags]).size >= group[:min_count]

              errors.add(
                :base,
                I18n.t(
                  "rss_polling.errors.required_tag_group",
                  category: category.name,
                  tag_group: group[:tag_group],
                  count: group[:min_count],
                  tags: group[:tags].join(", "),
                ),
              )
            end
        end

        def normalize_feed_url
          self.feed_url = feed_url&.strip
        end

        def normalize_tags
          return if discourse_tags.blank?

          self.discourse_tags =
            discourse_tags
              .map do |tag|
                if tag.is_a?(String)
                  tag
                elsif tag.is_a?(Numeric)
                  tag.to_s
                else
                  tag["name"] || tag[:name]
                end
              end
              .compact_blank
        end

        def tag_names
          discourse_tags&.join(",").presence
        end
      end

      model :user
      model :rss_feed, :build_rss_feed

      transaction do
        step :save_rss_feed
        step :log_change
      end

      private

      def fetch_user(params:)
        ::User.find_by_username(params.author_username)
      end

      def build_rss_feed(params:, user:)
        feed = params.id.present? ? RssFeed.find_by(id: params.id) : RssFeed.new
        return if feed.nil?

        feed.assign_attributes(
          url: params.feed_url,
          user: user,
          category_id: params.discourse_category_id,
          tags: params.tag_names,
          category_filter: params.feed_category_filter,
        )
        feed
      end

      def save_rss_feed(rss_feed:)
        rss_feed.save!
      end

      def log_change(guardian:, rss_feed:)
        Action::LogChange.call(
          actor: guardian.user,
          rss_feed:,
          action: rss_feed.previously_new_record? ? :create : :update,
        )
      end
    end
  end
end
