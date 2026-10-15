# frozen_string_literal: true

module PageObjects
  module Modals
    class EditTopicTimer < Base
      def select_timer_type(type)
        timer_type_selector = PageObjects::Components::DNativeSelect.new(".timer-type")
        timer_type_selector.select(type)
      end

      def set_relative_time_duration(duration)
        browser_root
          .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
          .and(browser_root.locator(".#{"relative-time-duration".to_s.split.join(".")}"))
          .filter(visible: true)
          .fill(duration)
      end

      INTERVAL_MAP = { "minutes" => "mins" }
      private_constant :INTERVAL_MAP

      def set_relative_time_interval(interval)
        select_kit = PageObjects::Components::SelectKit.new(".relative-time-intervals")
        select_kit.expand
        select_kit.select_row_by_value(INTERVAL_MAP[interval] || interval)
      end

      def click_save
        browser_root
          .locator("[id=#{"Set Timer".to_s.to_json}], [name=#{"Set Timer".to_s.to_json}]")
          .or(browser_root.get_by_role("button", name: "Set Timer"))
          .filter(visible: true)
          .click
      end
    end
  end
end
