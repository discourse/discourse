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

      def visit(start_date:, end_date:, traffic_type: nil, grouping: nil)
        path = "#{PATH}?end_date=#{end_date}&range=custom&start_date=#{start_date}"
        path += "&traffic_type=#{traffic_type}" if traffic_type
        path += "&grouping=#{grouping}" if grouping
        page.visit(path)
        self
      end

      def visit_default
        page.visit(PATH)
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

      def select_custom_datetime_range(start_date:, start_time:, end_date:, end_time:)
        picker = open_date_picker
        picker.set_datetime_range(start_date:, start_time:, end_date:, end_time:)
        picker.apply
        self
      end

      def open_date_picker
        find(".db-date-range__trigger").click
        PageObjects::Components::AdminDashboardDateRangePicker.new.tap(&:open?)
      end

      def has_grouping?(label)
        has_select?("Group by", selected: label)
      end

      def select_grouping(label)
        select(label, from: "Group by")
        self
      end

      def has_groupings?(*labels)
        has_select?("Group by", with_options: labels)
      end

      def hover_chart(fraction: 0.5)
        point_at_chart(fraction:) { |playwright_page, x, y| playwright_page.mouse.move(x, y) }
        self
      end

      def drag_chart(from:, to:)
        point_at_chart(fraction: from) do |playwright_page, start_x, start_y|
          surface = playwright_page.locator("[data-test-site-traffic-brush-surface]")
          box = surface.bounding_box
          end_x = box["x"] + box["width"] * to

          playwright_page.mouse.move(start_x, start_y)
          playwright_page.mouse.down
          playwright_page.mouse.move(end_x, start_y, steps: 10)
        end

        begin
          yield if block_given?
        ensure
          page.driver.with_playwright_page { |playwright_page| playwright_page.mouse.up }
        end

        self
      end

      def has_hover_marker?(fraction:, label:)
        return false if !has_css?("[data-test-site-traffic-hover-marker][aria-label='#{label}']")

        page.document.synchronize do
          surface = find("[data-test-site-traffic-brush-surface]").native.bounding_box
          marker = find("[data-test-site-traffic-hover-marker]").native.bounding_box
          expected_x = surface["x"] + surface["width"] * fraction
          actual_x = marker["x"] + marker["width"] / 2
          raise Capybara::ExpectationNotMet if (actual_x - expected_x).abs > 1

          true
        end
      end

      def has_brush_selection?
        has_css?("[data-test-site-traffic-brush-selection]")
      end

      def has_live_brush_range?(label)
        has_css?("[data-test-site-traffic-brush-live-range]", exact_text: label)
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
        has_css?("#{selector} a[href='#{label}']", exact_text: label)
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

      def point_at_chart(fraction:)
        page.driver.with_playwright_page do |playwright_page|
          surface = playwright_page.locator("[data-test-site-traffic-brush-surface]")
          surface.scroll_into_view_if_needed
          box = surface.bounding_box
          yield(
            playwright_page,
            box["x"] + box["width"] * fraction,
            box["y"] + box["height"] / 2,
          )
        end
      end

      def open_date_range
        open_date_picker
      end
    end
  end
end
