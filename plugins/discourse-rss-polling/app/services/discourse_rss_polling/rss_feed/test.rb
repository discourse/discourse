# frozen_string_literal: true

module DiscourseRssPolling
  class RssFeed
    class Test
      include Service::Base

      PREVIEW_LIMIT = 20

      params do
        attribute :feed_url, :string
        attribute :feed_category_filter, :string

        validates :feed_url, presence: true
      end

      step :fetch
      try { step :build_preview }

      private

      def fetch(params:)
        fetched = Action::FetchFeed.call(feed_url: params.feed_url)
        fail!(fetched.error) if fetched.error

        context[:fetched] = fetched
      end

      def build_preview(params:, fetched:)
        context[:preview] = Action::BuildPreview.call(
          feed_items: fetched.items.first(PREVIEW_LIMIT),
          feed_category_filter: params.feed_category_filter,
        )
      end
    end
  end
end
