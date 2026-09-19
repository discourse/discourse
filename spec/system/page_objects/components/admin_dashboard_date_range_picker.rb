# frozen_string_literal: true

module PageObjects
  module Components
    class AdminDashboardDateRangePicker < PageObjects::Components::Base
      SELECTOR = ".d-date-range-picker"

      def open?
        has_css?(SELECTOR)
      end

      def select_preset(label)
        find("#{SELECTOR}__preset", text: label).click
        self
      end

      def pick_day(date)
        parsed = Date.parse(date.to_s)
        find("#{SELECTOR}__day[aria-label='#{parsed.strftime("%B %-d, %Y")}']:not(.--muted)").click
        self
      end

      def apply
        find("#{SELECTOR}__apply").click
        self
      end
    end
  end
end
