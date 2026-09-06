# frozen_string_literal: true

module DiscourseRssPolling
  class RssFeed
    module FindById
      private

      def fetch_rss_feed(params:)
        RssFeed.find_by(id: params.id)
      end
    end
  end
end
