# frozen_string_literal: true

module DiscourseRssPolling
  class FeedAnalyzer
    WOULD_IMPORT = :would_import
    SKIPPED = :skipped

    def initialize(feed_category_filter: nil)
      @feed_category_filter = feed_category_filter.presence&.downcase
    end

    def evaluate(feed_item)
      return SKIPPED, :missing_content if feed_item.content.blank?
      return SKIPPED, :missing_title if feed_item.title.blank?

      if @feed_category_filter &&
           feed_item.categories.none? { |category|
             category.downcase.include?(@feed_category_filter)
           }
        return SKIPPED, :category_filter_mismatch
      end

      [WOULD_IMPORT, nil]
    end
  end
end
