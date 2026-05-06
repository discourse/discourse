# frozen_string_literal: true

module Jobs
  module DiscourseRssPolling
    class PollAllFeeds < ::Jobs::Scheduled
      every 5.minutes

      REDIS_KEY = "rss-polling-feeds-polled"

      def execute(args)
        return unless SiteSetting.rss_polling_enabled
        return unless not_polled_recently?

        ::DiscourseRssPolling::RssFeed.includes(:user).find_each(&:poll)
      end

      private

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
