# frozen_string_literal: true

module PageObjects
  module Components
    class AdminDashboardSiteTraffic < PageObjects::Components::Base
      def has_headline?(text)
        has_css?(".db-section__subintro h3", text: text)
      end

      def has_trend?(text)
        has_css?(".db-section__subintro h3", text: text)
      end

      def has_up_trend?(text)
        has_trend?(text)
      end

      def has_down_trend?(text)
        has_trend?(text)
      end

      def has_no_trend?
        has_no_css?(".db-section__subintro h3", text: "—")
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

      def has_see_details_link?
        has_css?("a.db-traffic__see-details")
      end

      def click_see_details
        find("a.db-traffic__see-details").click
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

      def hover_direct_traffic_tooltip
        find("[data-trigger][data-identifier='site-traffic-direct-traffic-tooltip']").hover
        self
      end

      def has_direct_traffic_tooltip?(text)
        Tooltips.new("site-traffic-direct-traffic-tooltip").present?(text: text)
      end

      def has_no_top_countries_card?
        has_no_top_card?("Top countries")
      end

      def has_no_top_referrers_card?
        has_no_top_card?("Top referrers")
      end

      def has_top_country_rows?(rows)
        within_top_card("Top countries") do
          next false unless has_css?(".db-traffic__list-row", count: rows.size)

          rows.each_with_index.all? do |row, index|
            nth =
              ".db-traffic__list-row:nth-child(#{index + 1})[data-test-country-code='#{row[:country]}']"
            has_css?(nth) && has_css?("#{nth} .db-traffic__percent", text: "#{row[:percent]}%")
          end
        end
      end

      def has_top_referrer_rows?(rows)
        within_top_card("Top referrers") do
          next false unless has_css?(".db-traffic__list-row", count: rows.size)

          rows.each_with_index.all? do |row, index|
            nth = ".db-traffic__list-row:nth-child(#{index + 1})"
            next false unless has_css?("#{nth} a.db-traffic__link", text: row[:referrer])
            next true unless row.key?(:percent)

            has_css?("#{nth} .db-traffic__percent", text: "#{row[:percent]}%")
          end
        end
      end

      def has_top_countries_empty_state?
        has_empty_state_in?("Top countries", "No country data for this period.")
      end

      def has_top_referrers_empty_state?
        has_empty_state_in?("Top referrers", "No referrer data for this period.")
      end

      def click_top_referrers_drilldown
        within_top_card("Top referrers") { find("h3.db-section__row-block-title a").click }
      end

      def click_top_countries_drilldown
        within_top_card("Top countries") { find("h3.db-section__row-block-title a").click }
      end

      def has_top_referrers_drilldown?
        within_top_card("Top referrers") { has_css?("h3.db-section__row-block-title a") }
      end

      def has_top_countries_drilldown?
        within_top_card("Top countries") { has_css?("h3.db-section__row-block-title a") }
      end

      def has_bounce_rate?(value)
        has_kpi_value?("bounce_rate", value)
      end

      def has_no_bounce_rate?
        has_no_kpi?("bounce_rate")
      end

      def has_average_session_duration?(value)
        has_kpi_value?("average_session_duration", value)
      end

      def has_no_average_session_duration?
        has_no_kpi?("average_session_duration")
      end

      def hover_bounce_rate_tooltip
        find("[data-test-kpi='bounce_rate'] [data-trigger]").hover
        self
      end

      def has_session_metric_tooltip?(text)
        Tooltips.new("site-traffic-bounce-rate-tooltip").present?(text: text)
      end

      private

      def has_kpi_value?(key, value)
        has_css?("[data-test-kpi='#{key}'] .db-section__metric-number", exact_text: value)
      end

      def has_no_kpi?(key)
        has_no_css?("[data-test-kpi='#{key}']")
      end

      def has_no_top_card?(title)
        has_no_css?(".db-section__row-block", text: title)
      end

      def within_top_card(title, &block)
        within(".db-section__row-block", text: title, &block)
      end

      def has_empty_state_in?(title, message)
        within_top_card(title) { has_css?(".db-traffic__list-empty", text: message) }
      end
    end
  end
end
