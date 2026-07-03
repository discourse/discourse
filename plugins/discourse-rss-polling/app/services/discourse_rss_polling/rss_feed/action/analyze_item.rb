# frozen_string_literal: true

module DiscourseRssPolling
  class RssFeed
    module Action
      class AnalyzeItem < Service::ActionBase
        WOULD_IMPORT = :would_import
        SKIPPED = :skipped

        option :feed_item
        option :feed_category_filter, optional: true

        def call
          return SKIPPED, :missing_content if feed_item.content.blank?
          return SKIPPED, :missing_title if feed_item.title.blank?
          return SKIPPED, :invalid_url unless importable_url?
          return SKIPPED, :category_filter_mismatch if filtered_out?

          [WOULD_IMPORT, nil]
        end

        private

        def importable_url?
          FeedUrl.http?(feed_item.url)
        end

        def filtered_out?
          filter = feed_category_filter.presence&.downcase
          return false if filter.nil?

          feed_item.categories.none? { |category| category.downcase.include?(filter) }
        end
      end
    end
  end
end
