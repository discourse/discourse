# frozen_string_literal: true

module PageObjects
  module Components
    class NestedRootAds < PageObjects::Components::Base
      def has_ads?(count:)
        has_css?(
          ".ad-connector--nested-root .house-creative.house-nested-roots-between",
          count: count,
        )
      end

      def has_ad_after?(post)
        has_css?(ad_after_selector(post))
      end

      def has_no_ad_after?(post)
        has_no_css?(ad_after_selector(post))
      end

      def has_no_post_bottom_ads?
        has_no_css?(".house-creative.house-post-bottom")
      end

      private

      def ad_after_selector(post)
        ".nested-post:has([data-post-number='#{post.post_number}']) + .ad-connector--nested-root"
      end
    end
  end
end
