# frozen_string_literal: true

module DiscourseRssPolling
  class RssFeed
    class SetEnabled
      include Service::Base
      include FindById

      params do
        attribute :id, :integer
        attribute :enabled

        validates :enabled, inclusion: { in: [true, false, "true", "false"] }

        def enabled?
          ActiveModel::Type::Boolean.new.cast(enabled)
        end
      end

      model :rss_feed

      transaction do
        step :change_status
        step :log_status_change
      end

      private

      def change_status(rss_feed:, params:)
        rss_feed.update!(enabled: params.enabled?)
      end

      def log_status_change(guardian:, rss_feed:)
        Action::LogChange.call(
          actor: guardian.user,
          rss_feed:,
          action: rss_feed.enabled? ? :enable : :disable,
        )
      end
    end
  end
end
