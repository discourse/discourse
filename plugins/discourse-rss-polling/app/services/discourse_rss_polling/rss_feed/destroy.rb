# frozen_string_literal: true

module DiscourseRssPolling
  class RssFeed
    class Destroy
      include Service::Base
      include FindById

      params { attribute :id, :integer }

      model :rss_feed

      transaction do
        step :destroy_feed
        step :log_deletion
      end

      private

      def destroy_feed(rss_feed:)
        rss_feed.destroy!
      end

      def log_deletion(guardian:, rss_feed:)
        Action::LogChange.call(actor: guardian.user, rss_feed:, action: :destroy)
      end
    end
  end
end
