# frozen_string_literal: true

module PageObjects
  module Components
    class AdminDashboardSearch < PageObjects::Components::Base
      SECTION = "[data-section-id='search']"

      BADGE_SELECTORS = { "No match" => ".db-pill.--neg", "Poor match" => ".db-pill.--neg" }.freeze

      def has_headline?(title, summary)
        has_css?("#{SECTION} .db-section__subintro h3", exact_text: title) &&
          has_css?("#{SECTION} .db-section__subintro p", exact_text: summary)
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
        ) && has_no_css?("#{kpi_selector("no_result_rate")} .db-section__metric-number.--neg")
      end

      def has_alert_no_result_rate_kpi?(value)
        has_css?(
          "#{kpi_selector("no_result_rate")} .db-section__metric-number.--neg",
          exact_text: value,
        )
      end

      def has_no_kpi_deltas?
        has_no_css?("#{SECTION} .db-delta")
      end

      def has_no_kpis?
        has_no_css?("#{SECTION} .db-section__metric")
      end

      def hover_total_searches_tooltip
        find("#{SECTION} [data-trigger][data-identifier='search-total-searches-tooltip']").hover
        self
      end

      def has_total_searches_tooltip?(text)
        Tooltips.new("search-total-searches-tooltip").present?(text: text)
      end

      def hover_no_result_rate_tooltip
        find("#{SECTION} [data-trigger][data-identifier='search-no-result-rate-tooltip']").hover
        self
      end

      def has_no_result_rate_tooltip?(text)
        Tooltips.new("search-no-result-rate-tooltip").present?(text: text)
      end

      def hover_trending_tooltip
        find("#{SECTION} [data-trigger][data-identifier='search-trending-tooltip']").hover
        self
      end

      def has_trending_tooltip?(text)
        Tooltips.new("search-trending-tooltip").present?(text: text)
      end

      def has_trending_rows?(rows)
        within_block("Trending searches") do
          next false unless has_css?("[data-test-search-term-row]", count: rows.size)

          rows.each_with_index.all? do |row, index|
            nth = "[data-test-search-term-row]:nth-child(#{index + 1})"
            has_css?("#{nth} a", text: row[:term]) && has_css?(nth, text: row[:searches].to_s)
          end
        end
      end

      def click_trending_term(term)
        within_block("Trending searches") do
          find("[data-test-search-term-row] a", text: term).click
        end
      end

      def has_no_trending_term?(term)
        within_block("Trending searches") do
          has_no_css?("[data-test-search-term-row] a", text: term)
        end
      end

      def has_trending_empty_state?(message)
        within_block("Trending searches") { has_text?(message) }
      end

      def has_content_gap_rows?(rows)
        within_block("Content gaps") do
          next false unless has_css?("[data-test-search-term-row]", count: rows.size)

          rows.each_with_index.all? do |row, index|
            nth = "[data-test-search-term-row]:nth-child(#{index + 1})"
            has_css?("#{nth} a", text: row[:term]) && has_css?(nth, text: row[:searches].to_s) &&
              has_css?("#{nth} #{BADGE_SELECTORS.fetch(row[:badge])}", text: row[:badge])
          end
        end
      end

      def click_content_gap_term(term)
        within_block("Content gaps") { find("[data-test-search-term-row] a", text: term).click }
      end

      def hover_content_gap_badge(term)
        within_block("Content gaps") do
          find("[data-test-search-term-row]", text: term).find(".db-pill").hover
        end
        self
      end

      def has_content_gap_badge_tooltip?(text)
        Tooltips.new("search-gap-badge-tooltip").present?(text: text)
      end

      def has_content_gaps_empty_state?(message)
        within_block("Content gaps") { has_text?(message) }
      end

      def has_logging_disabled_notice?(message)
        has_css?(SECTION, text: message) &&
          has_css?(
            "#{SECTION} a[href='/admin/site_settings/category/all_results?filter=log%20search%20queries']",
            text: "log search queries",
          )
      end

      def has_moderator_logging_disabled_notice?(message)
        has_css?(SECTION, text: message) && has_no_css?("#{SECTION} .db-section__callout a")
      end

      private

      def has_kpi?(type, value, improving_delta:, worsening_delta:)
        unless has_css?("#{kpi_selector(type)} .db-section__metric-number", exact_text: value)
          return false
        end
        if improving_delta.nil? && worsening_delta.nil?
          return has_no_css?("#{kpi_selector(type)} .db-delta")
        end

        modifier, text = improving_delta ? ["--pos", improving_delta] : ["--neg", worsening_delta]
        has_css?("#{kpi_selector(type)} .db-delta.#{modifier}", exact_text: text)
      end

      def kpi_selector(type)
        "#{SECTION} [data-test-search-kpi='#{type}']"
      end

      def within_block(title, &block)
        within(find("#{SECTION} .db-section__row-block", text: title), &block)
      end
    end
  end
end
