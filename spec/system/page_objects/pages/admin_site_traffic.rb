# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminSiteTraffic < PageObjects::Pages::Base
      SERIES_LABELS = {
        "logged-in-human" => "Logged-in human",
        "anonymous-human" => "Anonymous human",
        "likely-crawler" => "Likely crawler",
      }.freeze

      def visit_with_range(start_date:, end_date:)
        page.visit(
          "/admin/dashboard/traffic?#{{ start_date: start_date, end_date: end_date }.to_query}",
        )
        has_css?("[data-test-site-traffic-detail]")
        self
      end

      def has_page_title?
        has_css?("h1", exact_text: "Site Traffic Explorer")
      end

      def has_pageview_summary?(total:, logged_in_human:, anonymous_human:, likely_crawler:)
        has_metric?("Pageviews", total) && has_series_total?("Logged-in human", logged_in_human) &&
          has_series_total?("Anonymous human", anonymous_human) &&
          has_series_total?("Likely crawler", likely_crawler)
      end

      def has_session_summary?(distinct_sessions:, bounce_rate:, average_duration:)
        has_metric?("Distinct sessions", distinct_sessions) &&
          has_metric?("Bounce rate", bounce_rate) &&
          has_metric?("Average session duration", average_duration)
      end

      def has_chart_series?(series:, points:)
        series.all? do |label, total|
          has_exact_hidden_text?(
            "[data-test-traffic-series='#{label}']",
            "#{SERIES_LABELS.fetch(label)} #{total}",
          )
        end &&
          points.all? do |date, values|
            has_exact_hidden_text?("[data-test-traffic-point='#{date}']", values.join(" "))
          end
      end

      def has_crawler_scope_disclosure?
        has_exact_hidden_text?(
          "[data-test-crawler-scope]",
          "Likely crawler uses persisted scores for retained events. " \
            "Scoring is disabled or may lag, so human means not currently flagged, not verified human.",
        )
      end

      def has_session_scope_disclosure?
        has_exact_hidden_text?(
          "[data-test-session-scope]",
          "Overall for the unfiltered capped population. " \
            "Recent and cap-boundary sessions may be incomplete.",
        )
      end

      def has_breakdown_row?(title:, label:, pageviews:)
        within_breakdown(title) do
          all("[data-test-breakdown-row]", minimum: 1).any? do |row|
            label_element =
              row.first(":scope > [data-test-url-link]", minimum: 0, wait: 0) ||
                row.first(":scope > span:first-child", minimum: 0, wait: 0)

            label_element&.text == label &&
              row.find(".site-traffic-detail__row-count", wait: 0).text == pageviews
          end
        end
      end

      def click_breakdown_row(title:, label:)
        within_breakdown(title) do
          row = find("[data-test-breakdown-row]", text: /(?:\A|\s)#{Regexp.escape(label)}\s+\S+\z/)
          filter_control = row.first("[data-test-url-filter-area]", minimum: 0, wait: 0)

          (filter_control || row).click
        end
        self
      end

      def select_breakdown_tab(title:, tab:)
        within_breakdown(title) { find("[role='tab']", exact_text: tab).click }
        self
      end

      def has_filter_input?(value:)
        has_field?("topic-query-filter-input", with: value)
      end

      def clear_filters
        find(".topic-query-filter__clear-btn").click
        self
      end

      def has_top_row_count?(title:, count:)
        within_breakdown(title) { has_css?("[data-test-breakdown-row]", count: count) }
      end

      def expand(title)
        within_breakdown(title) { find("button", text: "View more").click }
        self
      end

      def has_expanded_table?(title:, row_count:)
        has_css?("[role='dialog'] table[aria-label='#{title}'] tbody tr", count: row_count)
      end

      def has_empty_state?
        has_css?("[role='status']", text: "No matching pageviews")
      end

      def has_loading_state_with_previous_total?(total:)
        has_css?("[data-test-traffic-loading][role='status']") && has_metric?("Pageviews", total)
      end

      def has_loading_state?
        has_css?("[data-test-traffic-loading][role='status']")
      end

      def has_error_state?(message:, retry_button: false, narrow_range: false)
        has_css?("[role='alert']", text: message) &&
          has_css?("button", text: "Retry", count: retry_button ? 1 : 0) &&
          has_css?("button", text: "Choose a narrower date range", count: narrow_range ? 1 : 0)
      end

      def retry
        find("button", text: "Retry").click
        self
      end

      def choose_narrower_range
        find("button", text: "Choose a narrower date range").click
        self
      end

      def has_date_range_controls?
        has_css?("[data-test-site-traffic-date-range]")
      end

      def has_partial_data_warning?(requested:, available:, analyzed:, analyzed_count:, event_cap:)
        has_css?(
          "[data-test-analysis-warning][role='status']",
          text:
            "Requested #{requested} Available #{available} Analyzed #{analyzed} " \
              "#{analyzed_count} pageviews analyzed #{event_cap} event cap Earlier eligible pageviews excluded",
        )
      end

      def has_no_partial_data_warning?
        has_no_css?("[data-test-analysis-warning]")
      end

      def has_no_generic_analysis_copy?
        has_no_text?(/Analyzing \d+ recent events/)
      end

      def has_safe_shareable_state?(country:, browser:)
        uri = URI(page.current_url)
        query = Rack::Utils.parse_query(uri.query)

        query["country"] == country && query["browser"] == browser
      end

      def has_no_sensitive_url_state?(*values)
        history_urls =
          page.evaluate_script(
            "performance.getEntriesByType('navigation').map((entry) => entry.name)",
          )

        values.none? do |value|
          page.current_url.include?(value) || history_urls.any? { |url| url.include?(value) }
        end
      end

      def browser_history_length
        page.evaluate_script("window.history.length")
      end

      private

      def has_metric?(label, value)
        metric =
          all("[data-test-metric]", count: 5).find do |element|
            element.find(".site-traffic-detail__metric-label", wait: 0).text == label
          end

        metric&.find(".site-traffic-detail__metric-value", wait: 0)&.text == value
      end

      def has_series_total?(label, value)
        has_exact_hidden_text?("[data-test-series-total]", "#{label} #{value}")
      end

      def has_exact_hidden_text?(selector, text)
        has_css?(selector, visible: :all, exact_text: text)
      end

      def within_breakdown(title, &block)
        within("[data-test-breakdown]", text: title, &block)
      end
    end
  end
end
