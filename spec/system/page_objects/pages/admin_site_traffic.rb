# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminSiteTraffic < PageObjects::Pages::Base
      def visit_with_range(start_date:, end_date:)
        page.visit(
          "/admin/dashboard/traffic?#{{
            start_date: start_date,
            end_date: end_date,
          }.to_query}",
        )
        has_css?("[data-test-site-traffic-detail]")
        self
      end

      def has_page_title?
        has_css?("h1", exact_text: "Site traffic")
      end

      def has_pageview_summary?(
        total:,
        logged_in_human:,
        anonymous_human:,
        likely_crawler:
      )
        has_metric?("Pageviews", total) &&
          has_series_total?("Logged-in human", logged_in_human) &&
          has_series_total?("Anonymous human", anonymous_human) &&
          has_series_total?("Likely crawler", likely_crawler)
      end

      def has_session_summary?(distinct_sessions:, bounce_rate:, average_duration:)
        has_metric?("Distinct sessions", distinct_sessions) &&
          has_metric?("Bounce rate", bounce_rate) &&
          has_metric?("Average session duration", average_duration) &&
          has_css?(
            "[data-test-session-kpis]",
            text: "Overall for analyzed period",
          )
      end

      def has_chart_series?(series:, points:)
        series.all? do |label, total|
          has_css?(
            "[data-test-traffic-series='#{label}']",
            text: total,
          )
        end && points.all? do |date, values|
          has_css?(
            "[data-test-traffic-point='#{date}']",
            text: values.join(" "),
            visible: :all,
          )
        end
      end

      def has_crawler_scope_disclosure?
        has_css?(
          "[data-test-crawler-scope]",
          text:
            "Likely crawler uses persisted scores for retained events. " \
              "Scoring is disabled or may lag, so human means not currently flagged, not verified human.",
        )
      end

      def has_session_scope_disclosure?
        has_css?(
          "[data-test-session-scope]",
          text:
            "Overall for the unfiltered capped population. " \
              "Recent and cap-boundary sessions may be incomplete.",
        )
      end

      def has_breakdown_row?(title:, label:, pageviews:)
        within_breakdown(title) do
          has_css?(
            "[data-test-breakdown-row]",
            text: "#{label} #{pageviews}",
          )
        end
      end

      def click_breakdown_row(title:, label:)
        within_breakdown(title) do
          find("[data-test-breakdown-row]", text: label).click
        end
        self
      end

      def has_filter_chip?(dimension:, value:)
        has_css?(
          "[data-test-filter-chip='#{dimension}']",
          text: value,
        )
      end

      def has_no_filter_chip?(dimension:)
        has_no_css?("[data-test-filter-chip='#{dimension}']")
      end

      def remove_filter(dimension)
        find("[data-test-filter-chip='#{dimension}'] button").click
        self
      end

      def has_top_row_count?(title:, count:)
        within_breakdown(title) do
          has_css?("[data-test-breakdown-row]", count: count)
        end
      end

      def expand(title)
        within_breakdown(title) do
          find("button", text: "View more").click
        end
        self
      end

      def has_expanded_table?(title:, row_count:)
        has_css?(
          "[role='dialog'] table[aria-label='#{title}'] tbody tr",
          count: row_count,
        )
      end

      def has_empty_state?
        has_css?("[role='status']", text: "No matching pageviews")
      end

      def has_loading_state_with_previous_total?(total:)
        has_css?("[data-test-traffic-loading][role='status']") &&
          has_metric?("Pageviews", total)
      end

      def has_loading_state?
        has_css?("[data-test-traffic-loading][role='status']")
      end

      def has_error_state?(message:, retry_button: false, narrow_range: false)
        has_css?("[role='alert']", text: message) &&
          has_css?("button", text: "Retry", count: retry_button ? 1 : 0) &&
          has_css?(
            "button",
            text: "Choose a narrower date range",
            count: narrow_range ? 1 : 0,
          )
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

      def has_partial_data_warning?(
        requested:,
        available:,
        analyzed:,
        analyzed_count:,
        event_cap:
      )
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
        fragment = Rack::Utils.parse_query(uri.fragment)

        fragment["country"] == country && fragment["browser"] == browser
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
        has_css?(
          "[data-test-metric]",
          text: "#{label} #{value}",
        )
      end

      def has_series_total?(label, value)
        has_css?(
          "[data-test-series-total]",
          text: "#{label} #{value}",
        )
      end

      def within_breakdown(title, &block)
        within("[data-test-breakdown]", text: title, &block)
      end
    end
  end
end
