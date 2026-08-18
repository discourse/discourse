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

      def has_timezone?(label)
        has_css?("[data-test-date-range-timezone]", exact_text: label)
      end

      def has_no_precision_mode?
        has_no_button?("Date") && has_no_button?("Date & time")
      end

      def has_datetime_range?(start_date:, start_time:, end_date:, end_time:)
        start_hours, start_minutes = start_time.split(":").map(&:to_i)
        end_hours, end_minutes = end_time.split(":").map(&:to_i)

        has_date_value?("[data-test-date-time-start]", start_date) &&
          has_date_value?("[data-test-date-time-end]", end_date) &&
          has_css?(
            "[data-test-date-time-start] .d-time-input .select-kit-header[data-value='#{start_hours * 60 + start_minutes}']",
          ) &&
          has_css?(
            "[data-test-date-time-end] .d-time-input .select-kit-header[data-value='#{end_hours * 60 + end_minutes}']",
          )
      end

      def set_datetime_range(start_date:, start_time:, end_date:, end_time:)
        find("[data-test-date-time-start] .date-picker").set(start_date)
        find("[data-test-date-time-end] .date-picker").set(end_date)
        select_time("[data-test-date-time-start]", start_time)
        select_time("[data-test-date-time-end]", end_time)
        self
      end

      def apply
        find("#{SELECTOR}__apply").click
        self
      end

      def cancel
        find("#{SELECTOR}__cancel").click
        self
      end

      private

      def has_date_value?(context, value)
        within(context) { has_field?("date", with: value) }
      end

      def select_time(context, time)
        hours, minutes = time.split(":").map(&:to_i)
        PageObjects::Components::SelectKit.new(
          "#{context} .d-time-input .select-kit",
        ).select_row_by_value(hours * 60 + minutes)
      end
    end
  end
end
