# frozen_string_literal: true

module DiscourseRssPolling
  class RssFeed
    module Action
      class LogChange < Service::ActionBase
        option :actor
        option :rss_feed
        option :action

        def call
          StaffActionLogger.new(actor).log_custom(
            "#{action}_rss_polling_feed",
            url: FeedUrl.redact(rss_feed.url),
          )
        end
      end
    end
  end
end
