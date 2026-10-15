# frozen_string_literal: true

module PageObjects
  module Components
    class AdminDashboardSiteTraffic < PageObjects::Components::Base
      def has_headline?(text)
        PlaywrightMatchers.contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator(".db-section__subintro h3").filter(visible: true),
        )
      end

      def has_trend?(text)
        PlaywrightMatchers.contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator(".db-section__subintro h3").filter(visible: true),
        )
      end

      def has_up_trend?(text)
        has_trend?(text)
      end

      def has_down_trend?(text)
        has_trend?(text)
      end

      def has_no_trend?
        PlaywrightMatchers.contain_text(
          [browser_text_pattern("—")],
          useInnerText: true,
        ).does_not_match?(browser_root.locator(".db-section__subintro h3").filter(visible: true))
      end

      def has_metric?(label, value)
        PlaywrightMatchers.contain_text(
          [browser_exact_text_pattern(value)],
          useInnerText: true,
        ).matches?(browser_root.locator(".db-section__metric-number").filter(visible: true)) &&
          PlaywrightMatchers.contain_text(
            [browser_exact_text_pattern(label)],
            useInnerText: true,
          ).matches?(browser_root.locator(".db-section__metric-label").filter(visible: true))
      end

      def has_no_metric?(label)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(label)],
          useInnerText: true,
        ).does_not_match?(browser_root.locator(".db-section__metric").filter(visible: true))
      end

      def has_chart?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".db-section__traffic-chart canvas").filter(visible: true),
        )
      end

      def has_see_details_link?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("a.db-traffic__see-details").filter(visible: true),
        )
      end

      def has_no_see_details_link?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("a.db-traffic__see-details").filter(visible: true),
        )
      end

      def click_see_details
        browser_root.locator("a.db-traffic__see-details").filter(visible: true).click
      end

      def hover_comparison_tooltip
        browser_root
          .locator("[data-trigger][data-identifier='site-traffic-comparison-tooltip']")
          .filter(visible: true)
          .hover
        self
      end

      def has_comparison_tooltip?(text)
        Tooltips.new("site-traffic-comparison-tooltip").present?(text: text)
      end

      def has_no_comparison_tooltip?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            "[data-trigger][data-identifier='site-traffic-comparison-tooltip']",
          ).filter(visible: true),
        )
      end

      def hover_logged_in_share_tooltip
        browser_root
          .locator("[data-trigger][data-identifier='site-traffic-logged-in-share-tooltip']")
          .filter(visible: true)
          .hover
        self
      end

      def has_logged_in_share_tooltip?(text)
        Tooltips.new("site-traffic-logged-in-share-tooltip").present?(text: text)
      end

      def hover_direct_traffic_tooltip
        browser_root
          .locator("[data-trigger][data-identifier='site-traffic-direct-traffic-tooltip']")
          .filter(visible: true)
          .hover
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

      def has_no_top_entry_urls_card?
        has_no_top_card?("Top entry URLs")
      end

      def has_top_country_rows?(rows)
        within_top_card("Top countries") do
          unless PlaywrightMatchers.have_count(rows.size).matches?(
                   browser_root.locator(".db-traffic__list-row").filter(visible: true),
                 )
            next false
          end

          rows.each_with_index.all? do |row, index|
            nth =
              ".db-traffic__list-row:nth-child(#{index + 1})[data-test-country-code='#{row[:country]}']"
            PlaywrightMatchers.have_count(0).does_not_match?(
              browser_root.locator("#{nth} .db-traffic__name[title='#{row[:name]}']").filter(
                visible: true,
              ),
            ) &&
              PlaywrightMatchers.contain_text(
                [browser_text_pattern("#{row[:percent]}%")],
                useInnerText: true,
              ).matches?(browser_root.locator("#{nth} .db-traffic__percent").filter(visible: true))
          end
        end
      end

      def has_top_referrer_rows?(rows)
        within_top_card("Top referrers") do
          unless PlaywrightMatchers.have_count(rows.size).matches?(
                   browser_root.locator(".db-traffic__list-row").filter(visible: true),
                 )
            next false
          end

          rows.each_with_index.all? do |row, index|
            nth = ".db-traffic__list-row:nth-child(#{index + 1})"
            unless PlaywrightMatchers.contain_text(
                     [browser_text_pattern(row[:referrer])],
                     useInnerText: true,
                   ).matches?(
                     browser_root.locator(
                       "#{nth} a.db-traffic__link[title='#{row[:referrer]}']",
                     ).filter(visible: true),
                   )
              next false
            end
            next true unless row.key?(:percent)

            PlaywrightMatchers.contain_text(
              [browser_text_pattern("#{row[:percent]}%")],
              useInnerText: true,
            ).matches?(browser_root.locator("#{nth} .db-traffic__percent").filter(visible: true))
          end
        end
      end

      def has_top_entry_url_rows?(rows)
        within_top_card("Top entry URLs") do
          unless PlaywrightMatchers.have_count(rows.size).matches?(
                   browser_root.locator(".db-traffic__list-row").filter(visible: true),
                 )
            next false
          end

          rows.each_with_index.all? do |row, index|
            nth = ".db-traffic__list-row:nth-child(#{index + 1})"
            PlaywrightMatchers.contain_text(
              [browser_text_pattern(row[:path])],
              useInnerText: true,
            ).matches?(
              browser_root.locator(
                "#{nth} a.db-traffic__link[href='#{row[:path]}'][title='#{row[:path]}']",
              ).filter(visible: true),
            ) &&
              PlaywrightMatchers.contain_text(
                [browser_exact_text_pattern("#{row[:percent]}%")],
                useInnerText: true,
              ).matches?(
                browser_root.locator("#{nth} .db-traffic__percent").filter(visible: true),
              ) &&
              PlaywrightMatchers.contain_text(
                [browser_exact_text_pattern("(#{row[:count]})")],
                useInnerText: true,
              ).matches?(browser_root.locator("#{nth} .db-traffic__count").filter(visible: true))
          end
        end
      end

      def has_top_countries_empty_state?
        has_empty_state_in?("Top countries", "No country data for this period.")
      end

      def has_top_referrers_empty_state?
        has_empty_state_in?("Top referrers", "No referrer data for this period.")
      end

      def has_top_entry_urls_empty_state?
        has_empty_state_in?("Top entry URLs", "No entry URL data for this period.")
      end

      def click_top_referrers_drilldown
        within_top_card("Top referrers") do
          browser_root.locator("h3.db-section__row-block-title a").filter(visible: true).click
        end
      end

      def click_top_countries_drilldown
        within_top_card("Top countries") do
          browser_root.locator("h3.db-section__row-block-title a").filter(visible: true).click
        end
      end

      def click_top_entry_urls_drilldown
        within_top_card("Top entry URLs") do
          browser_root.locator("h3.db-section__row-block-title a").filter(visible: true).click
        end
      end

      def has_top_referrers_drilldown?
        within_top_card("Top referrers") do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator("h3.db-section__row-block-title a").filter(visible: true),
          )
        end
      end

      def has_top_countries_drilldown?
        within_top_card("Top countries") do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator("h3.db-section__row-block-title a").filter(visible: true),
          )
        end
      end

      def has_top_entry_urls_drilldown?
        within_top_card("Top entry URLs") do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator("h3.db-section__row-block-title a").filter(visible: true),
          )
        end
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
        browser_root
          .locator("[data-test-kpi='bounce_rate'] [data-trigger]")
          .filter(visible: true)
          .hover
        self
      end

      def has_session_metric_tooltip?(text)
        Tooltips.new("site-traffic-bounce-rate-tooltip").present?(text: text)
      end

      private

      def has_kpi_value?(key, value)
        PlaywrightMatchers.contain_text(
          [browser_exact_text_pattern(value)],
          useInnerText: true,
        ).matches?(
          browser_root.locator("[data-test-kpi='#{key}'] .db-section__metric-number").filter(
            visible: true,
          ),
        )
      end

      def has_no_kpi?(key)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("[data-test-kpi='#{key}']").filter(visible: true),
        )
      end

      def has_no_top_card?(title)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(title)],
          useInnerText: true,
        ).does_not_match?(browser_root.locator(".db-section__row-block").filter(visible: true))
      end

      def within_top_card(title, &block)
        within_browser(
          browser_root
            .locator(".db-section__row-block")
            .filter(visible: true)
            .filter(hasText: title),
          &block
        )
      end

      def has_empty_state_in?(title, message)
        within_top_card(title) do
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(message)],
            useInnerText: true,
          ).matches?(browser_root.locator(".db-traffic__list-empty").filter(visible: true))
        end
      end
    end
  end
end
