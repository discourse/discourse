# frozen_string_literal: true

module DiscourseRssPolling
  class RssFeed
    class Poll
      include Service::Base
      include FindById

      params { attribute :id, :integer }

      model :rss_feed
      step :enqueue_poll
      step :log_poll

      private

      def enqueue_poll(rss_feed:)
        rss_feed.poll(force: true)
      end

      def log_poll(guardian:, rss_feed:)
        Action::LogChange.call(actor: guardian.user, rss_feed:, action: :poll)
      end
    end
  end
end
