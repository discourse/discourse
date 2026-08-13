# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminSiteTrafficExplorer < PageObjects::Pages::Base
      PATH = "/admin/dashboard/site-traffic-explorer"
      METRIC_KEYS = {
        "Pageviews" => "pageviews",
        "Distinct sessions" => "distinct_sessions",
        "Logged-in share" => "logged_in_share",
        "Bounce rate" => "bounce_rate",
        "Average session duration" => "average_session_duration",
      }.freeze
      FILTER_LABELS = {
        "traffic_type" => "Traffic type",
        "top_url" => "Top URL",
        "entry_url" => "Entry URL",
        "referrer" => "Referrer",
        "country" => "Country",
        "network" => "Network",
        "browser" => "Browser",
        "ip" => "IP address",
      }.freeze

      def visit(start_date:, end_date:, traffic_type: nil)
        path = "#{PATH}?end_date=#{end_date}&range=custom&start_date=#{start_date}"
        path += "&traffic_type=#{traffic_type}" if traffic_type
        page.visit(path)
        self
      end

      def go_back
        page.go_back
        self
      end

      def go_forward
        page.go_forward
        self
      end

      def has_page_title?
        has_css?("h1", exact_text: "Site Traffic Explorer")
      end

      def has_date_range?(text)
        has_button?(text)
      end

      def select_date_preset(label)
        open_date_range.select_preset(label)
        self
      end

      def select_custom_date_range(start_date:, end_date:)
        picker = open_date_range
        picker.pick_day(start_date)
        picker.pick_day(end_date)
        picker.apply
        self
      end

      def has_metric?(label:, value:)
        selector = "[data-test-site-traffic-metric='#{METRIC_KEYS.fetch(label)}']"
        has_css?(selector, text: label) && has_css?(selector, text: value)
      end

      def has_series_total?(label:, value:)
        has_css?("[data-test-traffic-series='#{label}']", text: value, visible: :all)
      end

      def has_no_series?(label:)
        has_no_css?("[data-test-traffic-series='#{label}']", visible: :all)
      end

      def has_partial_data_warning?(reason:)
        selector = "[data-test-site-traffic-partial-warning]"

        has_css?(selector, exact_text: reason) && has_no_css?("#{selector} button")
      end

      def has_no_partial_data_warning?
        has_no_css?("[data-test-site-traffic-partial-warning]")
      end

      def has_card_tabs?(card:, tabs:)
        tabs.all? do |tab|
          has_css?("[data-test-site-traffic-card='#{card}'] [role='tab']", exact_text: tab)
        end
      end

      def select_tab(card:, tab:)
        within("[data-test-site-traffic-card='#{card}']") do
          find("[role='tab']", exact_text: tab).click
        end
        self
      end

      def has_row?(card:, label:, count:)
        within("[data-test-site-traffic-card='#{card}']") do
          has_css?(
            "[data-test-site-traffic-row]",
            text: /#{Regexp.escape(label)}.*#{Regexp.escape(count)}/m,
          )
        end
      end

      def has_url_link?(card:, label:, href:)
        within("[data-test-site-traffic-card='#{card}']") do
          has_css?("a[href='#{href}'][title='#{label}']", exact_text: label)
        end
      end

      def filter_row(card:, label:)
        within("[data-test-site-traffic-card='#{card}']") do
          find("button[aria-label^='Filter by #{label},']").click
        end
        self
      end

      def has_filter_pill?(dimension:, label:)
        selector = "[data-test-site-traffic-filter-pill='#{dimension}']"
        remove_label =
          if dimension == "traffic_type"
            "Remove #{label} traffic filter"
          else
            "Remove #{FILTER_LABELS.fetch(dimension)} filter"
          end

        has_css?(selector, text: "#{FILTER_LABELS.fetch(dimension)} is #{label}", count: 1) &&
          has_css?("#{selector} button[aria-label='#{remove_label}']")
      end

      def has_no_filter_pills?
        has_no_css?("[data-test-site-traffic-filter-pill]")
      end

      def remove_filter(name, label: nil)
        remove_label =
          if name == "traffic_type"
            "Remove #{label} traffic filter"
          else
            "Remove #{FILTER_LABELS.fetch(name)} filter"
          end
        find("button[aria-label='#{remove_label}']").click
        self
      end

      def expand(card)
        within("[data-test-site-traffic-card='#{card}']") { find_button("View more").click }
        self
      end

      def has_expanded_table?(title:, column:)
        selector = ".site-traffic-breakdown-modal[role='dialog']"
        has_css?(selector, text: title) &&
          has_css?("#{selector} .d-table__header-cell", exact_text: column) &&
          has_css?("#{selector} .d-table__body .d-table__row")
      end

      def has_expanded_url_link?(label:)
        selector = ".site-traffic-breakdown-modal[role='dialog']"
        has_css?("#{selector} a[href='#{label}'][title='#{label}']", exact_text: label)
      end

      def filter_expanded_row(label:)
        within(".site-traffic-breakdown-modal[role='dialog']") do
          within("tr", text: label) { find("button[aria-label^='Filter by #{label},']").click }
        end
        self
      end

      def has_no_expanded_table?
        has_no_css?(".site-traffic-breakdown-modal[role='dialog']")
      end

      def has_empty_state?
        has_css?("[data-test-site-traffic-empty]", exact_text: "No matching pageviews")
      end

      private

      def open_date_range
        find(".db-date-range__trigger").click
        PageObjects::Components::AdminDashboardDateRangePicker.new.tap(&:open?)
      end
    end
  end
end
