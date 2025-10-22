# frozen_string_literal: true

module Jobs
  module DiscourseRssPolling
    class PollAllFeeds < ::Jobs::Scheduled
      every 5.minutes

      def execute(args)
        return unless SiteSetting.rss_polling_enabled

        poll_all_feeds if not_polled_recently?
      end

      private

      def poll_all_feeds
        ::DiscourseRssPolling::FeedSettingFinder.all.each(&:poll)
      end

      REDIS_KEY = "rss-polling-feeds-polled"

      def not_polled_recently?
        Discourse.redis.set(
          REDIS_KEY,
          1,
          ex: SiteSetting.rss_polling_frequency.minutes - 10.seconds,
          nx: true,
        )
      end
    end
  end
end
