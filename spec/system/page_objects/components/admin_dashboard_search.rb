# frozen_string_literal: true

module PageObjects
  module Components
    class AdminDashboardSearch < PageObjects::Components::Base
      SECTION = "[data-section-id='search']"

      BADGE_SELECTORS = { "No match" => ".db-pill.--neg", "Poor match" => ".db-pill.--neg" }.freeze

      def has_headline?(title, summary)
        contain_text([browser_exact_text_pattern(title)], useInnerText: true).matches?(
          browser_root.locator("#{SECTION} .db-section__subintro h3").filter(visible: true),
        ) &&
          contain_text([browser_exact_text_pattern(summary)], useInnerText: true).matches?(
            browser_root.locator("#{SECTION} .db-section__subintro p").filter(visible: true),
          )
      end

      def has_total_searches_kpi?(value, improving_delta: nil, worsening_delta: nil)
        has_kpi?(
          "total_searches",
          value,
          improving_delta: improving_delta,
          worsening_delta: worsening_delta,
        )
      end

      def has_no_result_rate_kpi?(value, improving_delta: nil, worsening_delta: nil)
        has_kpi?(
          "no_result_rate",
          value,
          improving_delta: improving_delta,
          worsening_delta: worsening_delta,
        ) &&
          have_count(0).matches?(
            browser_root.locator(
              "#{kpi_selector("no_result_rate")} .db-section__metric-number.--neg",
            ).filter(visible: true),
          )
      end

      def has_alert_no_result_rate_kpi?(value)
        contain_text([browser_exact_text_pattern(value)], useInnerText: true).matches?(
          browser_root.locator(
            "#{kpi_selector("no_result_rate")} .db-section__metric-number.--neg",
          ).filter(visible: true),
        )
      end

      def has_no_kpi_deltas?
        have_count(0).matches?(browser_root.locator("#{SECTION} .db-delta").filter(visible: true))
      end

      def has_no_kpis?
        have_count(0).matches?(
          browser_root.locator("#{SECTION} .db-section__metric").filter(visible: true),
        )
      end

      def hover_total_searches_tooltip
        browser_root
          .locator("#{SECTION} [data-trigger][data-identifier='search-total-searches-tooltip']")
          .filter(visible: true)
          .hover
        self
      end

      def has_total_searches_tooltip?(text)
        Tooltips.new("search-total-searches-tooltip").present?(text: text)
      end

      def hover_no_result_rate_tooltip
        browser_root
          .locator("#{SECTION} [data-trigger][data-identifier='search-no-result-rate-tooltip']")
          .filter(visible: true)
          .hover
        self
      end

      def has_no_result_rate_tooltip?(text)
        Tooltips.new("search-no-result-rate-tooltip").present?(text: text)
      end

      def hover_trending_tooltip
        browser_root
          .locator("#{SECTION} [data-trigger][data-identifier='search-trending-tooltip']")
          .filter(visible: true)
          .hover
        self
      end

      def has_trending_tooltip?(text)
        Tooltips.new("search-trending-tooltip").present?(text: text)
      end

      def has_trending_rows?(rows)
        within_block("Trending searches") do
          unless have_count(rows.size).matches?(
                   browser_root.locator("[data-test-search-term-row]").filter(visible: true),
                 )
            next false
          end

          rows.each_with_index.all? do |row, index|
            nth = "[data-test-search-term-row]:nth-child(#{index + 1})"
            contain_text([browser_text_pattern(row[:term])], useInnerText: true).matches?(
              browser_root.locator("#{nth} a").filter(visible: true),
            ) &&
              contain_text(
                [browser_text_pattern(row[:searches].to_s)],
                useInnerText: true,
              ).matches?(browser_root.locator(nth).filter(visible: true))
          end
        end
      end

      def click_trending_term(term)
        within_block("Trending searches") do
          browser_root
            .locator("[data-test-search-term-row] a")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(term))
            .click
        end
      end

      def has_no_trending_term?(term)
        within_block("Trending searches") do
          contain_text([browser_text_pattern(term)], useInnerText: true).does_not_match?(
            browser_root.locator("[data-test-search-term-row] a").filter(visible: true),
          )
        end
      end

      def has_trending_empty_state?(message)
        within_block("Trending searches") do
          contain_text(browser_text_pattern(message), useInnerText: true).matches?(browser_content)
        end
      end

      def has_content_gap_rows?(rows)
        within_block("Content gaps") do
          unless have_count(rows.size).matches?(
                   browser_root.locator("[data-test-search-term-row]").filter(visible: true),
                 )
            next false
          end

          rows.each_with_index.all? do |row, index|
            nth = "[data-test-search-term-row]:nth-child(#{index + 1})"
            contain_text([browser_text_pattern(row[:term])], useInnerText: true).matches?(
              browser_root.locator("#{nth} a").filter(visible: true),
            ) &&
              contain_text(
                [browser_text_pattern(row[:searches].to_s)],
                useInnerText: true,
              ).matches?(browser_root.locator(nth).filter(visible: true)) &&
              contain_text([browser_text_pattern(row[:badge])], useInnerText: true).matches?(
                browser_root.locator("#{nth} #{BADGE_SELECTORS.fetch(row[:badge])}").filter(
                  visible: true,
                ),
              )
          end
        end
      end

      def click_content_gap_term(term)
        within_block("Content gaps") do
          browser_root
            .locator("[data-test-search-term-row] a")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(term))
            .click
        end
      end

      def hover_content_gap_badge(term)
        within_block("Content gaps") do
          browser_root
            .locator("[data-test-search-term-row]")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(term))
            .locator(".db-pill")
            .filter(visible: true)
            .hover
        end
        self
      end

      def has_content_gap_badge_tooltip?(text)
        Tooltips.new("search-gap-badge-tooltip").present?(text: text)
      end

      def has_content_gaps_empty_state?(message)
        within_block("Content gaps") do
          contain_text(browser_text_pattern(message), useInnerText: true).matches?(browser_content)
        end
      end

      def has_logging_disabled_notice?(message)
        contain_text([browser_text_pattern(message)], useInnerText: true).matches?(
          browser_root.locator(SECTION).filter(visible: true),
        ) &&
          contain_text([browser_text_pattern("log search queries")], useInnerText: true).matches?(
            browser_root.locator(
              "#{SECTION} a[href='/admin/site_settings/category/all_results?filter=log%20search%20queries']",
            ).filter(visible: true),
          )
      end

      def has_moderator_logging_disabled_notice?(message)
        contain_text([browser_text_pattern(message)], useInnerText: true).matches?(
          browser_root.locator(SECTION).filter(visible: true),
        ) &&
          have_count(0).matches?(
            browser_root.locator("#{SECTION} .db-section__callout a").filter(visible: true),
          )
      end

      private

      def has_kpi?(type, value, improving_delta:, worsening_delta:)
        unless contain_text([browser_exact_text_pattern(value)], useInnerText: true).matches?(
                 browser_root.locator("#{kpi_selector(type)} .db-section__metric-number").filter(
                   visible: true,
                 ),
               )
          return false
        end
        if improving_delta.nil? && worsening_delta.nil?
          return(
            have_count(0).matches?(
              browser_root.locator("#{kpi_selector(type)} .db-delta").filter(visible: true),
            )
          )
        end

        modifier, text = improving_delta ? ["--pos", improving_delta] : ["--neg", worsening_delta]
        contain_text([browser_exact_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator("#{kpi_selector(type)} .db-delta.#{modifier}").filter(visible: true),
        )
      end

      def kpi_selector(type)
        "#{SECTION} [data-test-search-kpi='#{type}']"
      end

      def within_block(title, &block)
        within_browser(
          browser_root
            .locator("#{SECTION} .db-section__row-block")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(title)),
          &block
        )
      end
    end
  end
end
