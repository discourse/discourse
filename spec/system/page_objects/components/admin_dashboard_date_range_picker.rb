# frozen_string_literal: true

module PageObjects
  module Components
    class AdminDashboardDateRangePicker < PageObjects::Components::Base
      SELECTOR = ".d-date-range-picker"

      def open?
        have_count(0).does_not_match?(browser_root.locator(SELECTOR).filter(visible: true))
      end

      def select_preset(label)
        browser_root
          .locator("#{SELECTOR}__preset")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(label))
          .click
        self
      end

      def pick_day(date)
        parsed = Date.parse(date.to_s)
        browser_root
          .locator("#{SELECTOR}__day[aria-label='#{parsed.strftime("%B %-d, %Y")}']:not(.--muted)")
          .filter(visible: true)
          .click
        self
      end

      def apply
        browser_root.locator("#{SELECTOR}__apply").filter(visible: true).click
        self
      end
    end
  end
end
