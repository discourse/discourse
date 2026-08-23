# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminSiteTrafficExplorer < PageObjects::Pages::Base
      PATH = "/admin/dashboard/site-traffic-explorer"
      METRIC_KEYS = {
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
          has_css?("a[href='#{href}']", exact_text: label)
        end
      end

      def filter_row(card:, label:)
        within("[data-test-site-traffic-card='#{card}']") do
          find("input[type='checkbox'][aria-label^='Filter by #{label},']").click
        end
        find("[data-test-site-traffic-apply-filters]").click
        self
      end

      def filter_by_clicking_row(card:, label:)
        within("[data-test-site-traffic-card='#{card}']") do
          within("[data-test-site-traffic-row]", text: label) do
            find(".site-traffic-explorer__row-checkbox").click
          end
        end
        find("[data-test-site-traffic-apply-filters]").click
        self
      end

      def select_filter_row(card:, label:)
        within("[data-test-site-traffic-card='#{card}']") do
          find("input[type='checkbox'][aria-label^='Filter by #{label},']").click
        end
        self
      end

      def has_filter_row_selected?(card:, label:)
        within("[data-test-site-traffic-card='#{card}']") do
          has_css?("input[type='checkbox'][aria-label^='Filter by #{label},']:checked")
        end
      end

      def has_filter_row_unselected?(card:, label:)
        within("[data-test-site-traffic-card='#{card}']") do
          has_css?("input[type='checkbox'][aria-label^='Filter by #{label},']:not(:checked)")
        end
      end

      def has_filter_pill?(dimension:, label:)
        selector = "[data-test-site-traffic-filter-pill='#{dimension}']"
        remove_label = "Remove #{FILTER_LABELS.fetch(dimension)} filter"
        expected_text = "#{FILTER_LABELS.fetch(dimension)}: #{label}".gsub(/\s+/, "")

        has_css?(selector, count: 1) &&
          find(selector).text.gsub(/\s+/, "").include?(expected_text) &&
          has_css?("#{selector} button[aria-label='#{remove_label}']")
      end

      def has_no_filter_pills?
        has_no_css?("[data-test-site-traffic-filter-pill]")
      end

      def has_grouped_filter_pill?(dimension:, label:)
        selector = "[data-test-site-traffic-filter-pill='#{dimension}'] .fk-d-menu__trigger"

        has_css?(selector, count: 1) &&
          find(selector).text.gsub(/\s+/, "").include?(label.gsub(/\s+/, ""))
      end

      def expand_filter_pill(dimension)
        within("[data-test-site-traffic-filter-pill='#{dimension}']") do
          find(".fk-d-menu__trigger").click
        end
        self
      end

      def has_filter_dropdown?(values:)
        row_selector = "[data-test-site-traffic-filter-dropdown-value]"
        value_selector = "#{row_selector} .d-button-label"

        has_css?(row_selector, count: values.length) &&
          values.all? { |value| has_css?(value_selector, exact_text: value, count: 1) }
      end

      def has_no_filter_dropdown?
        has_no_css?("[data-test-site-traffic-filter-dropdown]")
      end

      def remove_filter_value(value)
        within("[data-test-site-traffic-filter-dropdown]") { find_button("Remove #{value}").click }
        self
      end

      def has_apply_filters?(count:)
        selector = "[data-test-site-traffic-apply-filters]"

        has_css?(selector, count: 1) &&
          has_css?(
            "#{selector} .site-traffic-explorer__filter-apply-pending-count",
            exact_text: count.to_s,
            count: 1,
          )
      end

      def has_no_apply_filters?
        has_no_button?("Apply", exact: false)
      end

      def apply_filters
        find("[data-test-site-traffic-apply-filters]").click
        self
      end

      def clear_all
        find_button("Clear all", exact: true).click
        self
      end

      def remove_filter(name, label: nil)
        remove_label = "Remove #{FILTER_LABELS.fetch(name)} filter"
        selector = "[data-test-site-traffic-filter-pill='#{name}']"
        if label && has_css?("#{selector} .fk-d-menu__trigger", wait: 0)
          within(selector) { find(".fk-d-menu__trigger").click }
          within("[data-test-site-traffic-filter-dropdown]") do
            find_button("Remove #{label}").click
          end
        else
          find("button[aria-label='#{remove_label}']").click
        end
        if has_css?("[data-test-site-traffic-apply-filters]", wait: 0)
          find("[data-test-site-traffic-apply-filters]").click
        end
        self
      end

      def expand(card)
        within("[data-test-site-traffic-card='#{card}']") { find_button("View more").click }
        self
      end

      def has_expanded_breakdown?(title:)
        selector = ".site-traffic-breakdown-modal[role='dialog']"
        has_css?(selector, text: title) && has_css?("#{selector} [data-test-site-traffic-row]")
      end

      def has_expanded_url_link?(label:)
        selector = ".site-traffic-breakdown-modal[role='dialog']"
        has_css?("#{selector} a[href='#{label}']", exact_text: label)
      end

      def select_expanded_filter_row(label:)
        within(".site-traffic-breakdown-modal[role='dialog']") do
          within("[data-test-site-traffic-row]", text: label) do
            find("input[type='checkbox'][aria-label^='Filter by #{label},']").click
          end
        end
        self
      end

      def apply_expanded_filters
        within(".site-traffic-breakdown-modal[role='dialog']") do
          find_button("Apply", exact: true).click
        end
        self
      end

      def has_no_expanded_breakdown?
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
