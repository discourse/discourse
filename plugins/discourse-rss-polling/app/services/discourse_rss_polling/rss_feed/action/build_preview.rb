# frozen_string_literal: true

module DiscourseRssPolling
  class RssFeed
    module Action
      class BuildPreview < Service::ActionBase
        option :feed_items
        option :feed_category_filter, optional: true

        def call
          imported = ImportedTopics.call(feed_items:)

          feed_items.map do |feed_item|
            status, reason = AnalyzeItem.call(feed_item:, feed_category_filter:)

            if status == AnalyzeItem::WOULD_IMPORT && (topic_url = imported[feed_item])
              feed_item.outcome(status: :already_imported, reason:, topic_url:)
            else
              feed_item.outcome(status:, reason:)
            end
          end
        end
      end
    end
  end
end
