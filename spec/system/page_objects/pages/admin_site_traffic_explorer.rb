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
        "language" => "Language",
        "ip" => "IP address",
      }.freeze

      def visit(start_date:, end_date:, traffic_type: nil)
        path = "#{PATH}?end_date=#{end_date}&range=custom&start_date=#{start_date}"
        path += "&traffic_type=#{traffic_type}" if traffic_type
        browser_page.goto(path).tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def go_back
        browser_page.go_back.tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def go_forward
        browser_page.go_forward.tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_page_title?
        PlaywrightMatchers.contain_text(
          [browser_exact_text_pattern("Site Traffic Explorer")],
          useInnerText: true,
        ).matches?(browser_root.locator("h1").filter(visible: true))
      end

      def has_date_range?(text)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root
            .get_by_role("button")
            .and(
              browser_root.locator("[id=#{text.to_s.to_json}], [name=#{text.to_s.to_json}]").or(
                browser_root.get_by_role("button", name: text),
              ),
            )
            .filter(visible: true),
        )
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
        PlaywrightMatchers.contain_text([browser_text_pattern(label)], useInnerText: true).matches?(
          browser_root.locator(selector).filter(visible: true),
        ) &&
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(value)],
            useInnerText: true,
          ).matches?(browser_root.locator(selector).filter(visible: true))
      end

      def has_series_total?(label:, value:)
        PlaywrightMatchers.contain_text([browser_text_pattern(value)], useInnerText: true).matches?(
          browser_root.locator("[data-test-traffic-series='#{label}']"),
        )
      end

      def has_no_series?(label:)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("[data-test-traffic-series='#{label}']"),
        )
      end

      def toggle_chart_legend(label:)
        browser_page.evaluate(
          "function(args) { return new Promise(resolve => { args.push(resolve); (function() { #{
            <<~JAVASCRIPT
          const label = arguments[0];
          const done = arguments[1];

          require("discourse/lib/load-chart-js").default().then((Chart) => {
            const chart = Chart.getChart(
              document.querySelector(".admin-report-stacked-chart canvas")
            );
            const legendItem = chart.legend.legendItems.find(
              (item) => item.text === label
            );

            chart.options.plugins.legend.onClick(null, legendItem, chart.legend);
            done();
          });
        JAVASCRIPT
          } }).apply(this, args); }); }",
          arg: browser_arguments(label),
        )

        self
      end

      def has_selected_legend_item?(label:)
        legend_item_selected?(label:)
      end

      def has_deselected_legend_item?(label:)
        legend_item_selected?(label:, selected: false)
      end

      def has_partial_data_warning?(reason:)
        selector = "[data-test-site-traffic-partial-warning]"

        PlaywrightMatchers.contain_text(
          [browser_exact_text_pattern(reason)],
          useInnerText: true,
        ).matches?(browser_root.locator(selector).filter(visible: true)) &&
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator("#{selector} button").filter(visible: true),
          )
      end

      def has_no_partial_data_warning?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("[data-test-site-traffic-partial-warning]").filter(visible: true),
        )
      end

      def has_card_tabs?(card:, tabs:)
        tabs.all? do |tab|
          PlaywrightMatchers.contain_text(
            [browser_exact_text_pattern(tab)],
            useInnerText: true,
          ).matches?(
            browser_root.locator("[data-test-site-traffic-card='#{card}'] [role='tab']").filter(
              visible: true,
            ),
          )
        end
      end

      def select_tab(card:, tab:)
        within_browser(
          browser_root.locator("[data-test-site-traffic-card='#{card}']").filter(visible: true),
        ) do
          browser_root
            .locator("[role='tab']")
            .filter(visible: true)
            .filter(hasText: browser_exact_text_pattern(tab))
            .click
        end
        self
      end

      def has_row?(card:, label:, count:)
        within_browser(
          browser_root.locator("[data-test-site-traffic-card='#{card}']").filter(visible: true),
        ) do
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(/#{Regexp.escape(label)}.*#{Regexp.escape(count)}/m)],
            useInnerText: true,
          ).matches?(browser_root.locator("[data-test-site-traffic-row]").filter(visible: true))
        end
      end

      def has_rows?(card:, rows:)
        within_browser(
          browser_root.locator("[data-test-site-traffic-card='#{card}']").filter(visible: true),
        ) do
          unless PlaywrightMatchers.have_count(rows.size).matches?(
                   browser_root.locator("[data-test-site-traffic-row]").filter(visible: true),
                 )
            return false
          end

          actual_rows =
            browser_root
              .locator("[data-test-site-traffic-row]")
              .filter(visible: true)
              .tap { |elements| elements.first.wait_for(state: "visible") }
              .all
              .map do |row|
                {
                  label:
                    row
                      .locator(".site-traffic-explorer__dimension-text")
                      .filter(visible: true)
                      .inner_text
                      .strip,
                  count:
                    row
                      .locator(".site-traffic-explorer__row-count")
                      .filter(visible: true)
                      .inner_text
                      .strip,
                }
              end

          actual_rows == rows
        end
      end

      def has_url_link?(card:, label:, href:)
        within_browser(
          browser_root.locator("[data-test-site-traffic-card='#{card}']").filter(visible: true),
        ) do
          PlaywrightMatchers.contain_text(
            [browser_exact_text_pattern(label)],
            useInnerText: true,
          ).matches?(browser_root.locator("a[href='#{href}']").filter(visible: true))
        end
      end

      def filter_row(card:, label:)
        within_browser(
          browser_root.locator("[data-test-site-traffic-card='#{card}']").filter(visible: true),
        ) do
          browser_root
            .locator("input[type='checkbox'][aria-label^='Filter by #{label},']")
            .filter(visible: true)
            .click
        end
        browser_root.locator("[data-test-site-traffic-apply-filters]").filter(visible: true).click
        self
      end

      def filter_by_clicking_row(card:, label:)
        within_browser(
          browser_root.locator("[data-test-site-traffic-card='#{card}']").filter(visible: true),
        ) do
          within_browser(
            browser_root
              .locator("[data-test-site-traffic-row]")
              .filter(visible: true)
              .filter(hasText: browser_text_pattern(label)),
          ) do
            browser_root.locator(".site-traffic-explorer__row-checkbox").filter(visible: true).click
          end
        end
        browser_root.locator("[data-test-site-traffic-apply-filters]").filter(visible: true).click
        self
      end

      def select_filter_row(card:, label:)
        within_browser(
          browser_root.locator("[data-test-site-traffic-card='#{card}']").filter(visible: true),
        ) do
          browser_root
            .locator("input[type='checkbox'][aria-label^='Filter by #{label},']")
            .filter(visible: true)
            .click
        end
        self
      end

      def has_filter_row_selected?(card:, label:)
        within_browser(
          browser_root.locator("[data-test-site-traffic-card='#{card}']").filter(visible: true),
        ) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(
              "input[type='checkbox'][aria-label^='Filter by #{label},']:checked",
            ).filter(visible: true),
          )
        end
      end

      def has_filter_row_unselected?(card:, label:)
        within_browser(
          browser_root.locator("[data-test-site-traffic-card='#{card}']").filter(visible: true),
        ) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(
              "input[type='checkbox'][aria-label^='Filter by #{label},']:not(:checked)",
            ).filter(visible: true),
          )
        end
      end

      def has_filter_pill?(dimension:, label:)
        selector = "[data-test-site-traffic-filter-pill='#{dimension}']"
        remove_label = "Remove #{FILTER_LABELS.fetch(dimension)} filter"
        expected_text = "#{FILTER_LABELS.fetch(dimension)}: #{label}".gsub(/\s+/, "")

        PlaywrightMatchers.have_count(1).matches?(
          browser_root.locator(selector).filter(visible: true),
        ) &&
          browser_root
            .locator(selector)
            .filter(visible: true)
            .inner_text
            .strip
            .gsub(/\s+/, "")
            .include?(expected_text) &&
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator("#{selector} button[aria-label='#{remove_label}']").filter(
              visible: true,
            ),
          )
      end

      def has_no_filter_pills?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("[data-test-site-traffic-filter-pill]").filter(visible: true),
        )
      end

      def has_grouped_filter_pill?(dimension:, label:)
        selector = "[data-test-site-traffic-filter-pill='#{dimension}'] .fk-d-menu__trigger"

        PlaywrightMatchers.have_count(1).matches?(
          browser_root.locator(selector).filter(visible: true),
        ) &&
          browser_root
            .locator(selector)
            .filter(visible: true)
            .inner_text
            .strip
            .gsub(/\s+/, "")
            .include?(label.gsub(/\s+/, ""))
      end

      def expand_filter_pill(dimension)
        within_browser(
          browser_root.locator("[data-test-site-traffic-filter-pill='#{dimension}']").filter(
            visible: true,
          ),
        ) { browser_root.locator(".fk-d-menu__trigger").filter(visible: true).click }
        self
      end

      def has_filter_dropdown?(values:)
        row_selector = "[data-test-site-traffic-filter-dropdown-value]"
        value_selector = "#{row_selector} .d-button-label"

        PlaywrightMatchers.have_count(values.length).matches?(
          browser_root.locator(row_selector).filter(visible: true),
        ) &&
          values.all? do |value|
            PlaywrightMatchers.have_count(1).matches?(
              browser_root
                .locator(value_selector)
                .filter(visible: true)
                .filter(hasText: browser_exact_text_pattern(value)),
            )
          end
      end

      def has_no_filter_dropdown?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("[data-test-site-traffic-filter-dropdown]").filter(visible: true),
        )
      end

      def remove_filter_value(value)
        within_browser(
          browser_root.locator("[data-test-site-traffic-filter-dropdown]").filter(visible: true),
        ) do
          browser_root
            .get_by_role("button")
            .and(
              browser_root.locator(
                "[id=#{"Remove #{value}".to_s.to_json}], [name=#{"Remove #{value}".to_s.to_json}]",
              ).or(browser_root.get_by_role("button", name: "Remove #{value}")),
            )
            .filter(visible: true)
            .click
        end
        self
      end

      def has_apply_filters?(count:)
        selector = "[data-test-site-traffic-apply-filters]"

        PlaywrightMatchers.have_count(1).matches?(
          browser_root.locator(selector).filter(visible: true),
        ) &&
          PlaywrightMatchers.have_count(1).matches?(
            browser_root
              .locator("#{selector} .d-button-label")
              .filter(visible: true)
              .filter(hasText: browser_exact_text_pattern("Apply")),
          ) &&
          PlaywrightMatchers.have_count(1).matches?(
            browser_root
              .locator("#{selector} .site-traffic-explorer__filter-apply-pending-count")
              .filter(visible: true)
              .filter(hasText: browser_exact_text_pattern(count.to_s)),
          )
      end

      def has_no_apply_filters?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("[data-test-site-traffic-apply-filters]").filter(visible: true),
        )
      end

      def apply_filters
        browser_root.locator("[data-test-site-traffic-apply-filters]").filter(visible: true).click
        self
      end

      def clear_all
        browser_root
          .get_by_role("button")
          .and(
            browser_root.locator(
              "[id=#{"Clear all".to_s.to_json}], [name=#{"Clear all".to_s.to_json}]",
            ).or(browser_root.get_by_role("button", name: "Clear all")),
          )
          .filter(visible: true)
          .click
        self
      end

      def remove_filter(name, label: nil)
        remove_label = "Remove #{FILTER_LABELS.fetch(name)} filter"
        selector = "[data-test-site-traffic-filter-pill='#{name}']"
        if label &&
             browser_root.locator("#{selector} .fk-d-menu__trigger").filter(visible: true).count !=
               0
          within_browser(selector) do
            browser_root.locator(".fk-d-menu__trigger").filter(visible: true).click
          end
          within_browser(
            browser_root.locator("[data-test-site-traffic-filter-dropdown]").filter(visible: true),
          ) do
            browser_root
              .get_by_role("button")
              .and(
                browser_root.locator(
                  "[id=#{"Remove #{label}".to_s.to_json}], [name=#{"Remove #{label}".to_s.to_json}]",
                ).or(browser_root.get_by_role("button", name: "Remove #{label}")),
              )
              .filter(visible: true)
              .click
          end
        else
          browser_root.locator("button[aria-label='#{remove_label}']").filter(visible: true).click
        end
        if browser_root
             .locator("[data-test-site-traffic-apply-filters]")
             .filter(visible: true)
             .count != 0
          browser_root.locator("[data-test-site-traffic-apply-filters]").filter(visible: true).click
        end
        self
      end

      def expand(card)
        within_browser(
          browser_root.locator("[data-test-site-traffic-card='#{card}']").filter(visible: true),
        ) do
          browser_root
            .get_by_role("button")
            .and(
              browser_root.locator(
                "[id=#{"View more".to_s.to_json}], [name=#{"View more".to_s.to_json}]",
              ).or(browser_root.get_by_role("button", name: "View more")),
            )
            .filter(visible: true)
            .click
        end
        self
      end

      def has_expanded_breakdown?(title:)
        selector = ".site-traffic-breakdown-modal[role='dialog']"
        PlaywrightMatchers.contain_text([browser_text_pattern(title)], useInnerText: true).matches?(
          browser_root.locator(selector).filter(visible: true),
        ) &&
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator("#{selector} [data-test-site-traffic-row]").filter(visible: true),
          )
      end

      def has_expanded_url_link?(label:)
        selector = ".site-traffic-breakdown-modal[role='dialog']"
        PlaywrightMatchers.contain_text(
          [browser_exact_text_pattern(label)],
          useInnerText: true,
        ).matches?(browser_root.locator("#{selector} a[href='#{label}']").filter(visible: true))
      end

      def select_expanded_filter_row(label:)
        within_browser(
          browser_root.locator(".site-traffic-breakdown-modal[role='dialog']").filter(
            visible: true,
          ),
        ) do
          within_browser(
            browser_root
              .locator("[data-test-site-traffic-row]")
              .filter(visible: true)
              .filter(hasText: browser_text_pattern(label)),
          ) do
            browser_root
              .locator("input[type='checkbox'][aria-label^='Filter by #{label},']")
              .filter(visible: true)
              .click
          end
        end
        self
      end

      def apply_expanded_filters
        within_browser(
          browser_root.locator(".site-traffic-breakdown-modal[role='dialog']").filter(
            visible: true,
          ),
        ) do
          browser_root
            .get_by_role("button")
            .and(
              browser_root.locator(
                "[id=#{"Apply filters".to_s.to_json}], [name=#{"Apply filters".to_s.to_json}]",
              ).or(browser_root.get_by_role("button", name: "Apply filters")),
            )
            .filter(visible: true)
            .click
        end
        self
      end

      def has_no_expanded_breakdown?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".site-traffic-breakdown-modal[role='dialog']").filter(
            visible: true,
          ),
        )
      end

      def has_empty_state?
        PlaywrightMatchers.contain_text(
          [browser_exact_text_pattern("No matching pageviews")],
          useInnerText: true,
        ).matches?(browser_root.locator("[data-test-site-traffic-empty]").filter(visible: true))
      end

      private

      def legend_item_selected?(label:, selected: true)
        browser_root.locator(".admin-report-stacked-chart canvas").wait_for(state: "visible")
        result =
          browser_page.wait_for_function(
            <<~JS,
          async ({label, selected}) => {
            const Chart = await require("discourse/lib/load-chart-js").default();
            const chart = Chart.getChart(document.querySelector(".admin-report-stacked-chart canvas"));
            const item = chart?.legend?.legendItems.find(item => item.text === label);
            return Boolean(item) && chart.isDatasetVisible(item.datasetIndex) === selected;
          }
        JS
            arg: {
              label: label,
              selected: selected,
            },
            timeout: Capybara.default_max_wait_time * 1000,
          )
        result.dispose
        true
      end

      def open_date_range
        browser_root.locator(".db-date-range__trigger").filter(visible: true).click
        PageObjects::Components::AdminDashboardDateRangePicker.new.tap(&:open?)
      end
    end
  end
end
