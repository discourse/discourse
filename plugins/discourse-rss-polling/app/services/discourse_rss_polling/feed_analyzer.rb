# frozen_string_literal: true

module DiscourseRssPolling
  # Decides whether a feed item would be imported or skipped (and why). This is
  # the single source of truth for that decision, shared by the poll job (for
  # the actual skip + verbose logging) and the "test feed" dry-run so the two
  # always agree.
  class FeedAnalyzer
    WOULD_IMPORT = :would_import
    SKIPPED = :skipped

    def initialize(feed_category_filter: nil)
      @feed_category_filter = feed_category_filter.presence
    end

    # Returns [status, reason]. status is WOULD_IMPORT or SKIPPED; reason is a
    # symbol naming why the item was skipped (nil when it would be imported).
    def evaluate(feed_item)
      return SKIPPED, :missing_content if feed_item.content.blank?
      return SKIPPED, :missing_title if feed_item.title.blank?

      if @feed_category_filter &&
           feed_item.categories.none? { |category| category.include?(@feed_category_filter) }
        return SKIPPED, :category_filter_mismatch
      end

      [WOULD_IMPORT, nil]
    end
  end
end
