# frozen_string_literal: true

module PageObjects
  module Components
    class AdminDashboardSiteTraffic < PageObjects::Components::Base
      def has_headline?(text)
        has_css?(".db-traffic__headline", text: text)
      end

      def has_trend?(text)
        has_css?(".db-traffic__trend", text: text)
      end

      def has_up_trend?(text)
        has_css?(".db-traffic__trend.--up", text: text)
      end

      def has_down_trend?(text)
        has_css?(".db-traffic__trend.--down", text: text)
      end

      def has_no_trend?
        has_no_css?(".db-traffic__trend")
      end

      def has_metric?(label, value)
        has_css?(".db-section__metric-number", exact_text: value) &&
          has_css?(".db-section__metric-label", exact_text: label)
      end

      def has_no_metric?(label)
        has_no_css?(".db-section__metric", text: label)
      end

      def has_chart?
        has_css?(".db-section__traffic-chart canvas")
      end

      def hover_comparison_tooltip
        find("[data-trigger][data-identifier='site-traffic-comparison-tooltip']").hover
        self
      end

      def has_comparison_tooltip?(text)
        Tooltips.new("site-traffic-comparison-tooltip").present?(text: text)
      end

      def has_no_comparison_tooltip?
        has_no_css?("[data-trigger][data-identifier='site-traffic-comparison-tooltip']")
      end

      def hover_logged_in_share_tooltip
        find("[data-trigger][data-identifier='site-traffic-logged-in-share-tooltip']").hover
        self
      end

      def has_logged_in_share_tooltip?(text)
        Tooltips.new("site-traffic-logged-in-share-tooltip").present?(text: text)
      end
    end
  end
end
