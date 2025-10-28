# frozen_string_literal: true

module PageObjects
  module Modals
    class EditTopicTimer < Base
      def select_timer_type(type)
        timer_type_selector = PageObjects::Components::DSelect.new(".timer-type")
        timer_type_selector.select(type)
      end

      def set_relative_time_duration(duration)
        fill_in(class: "relative-time-duration", with: duration)
      end

      INTERVAL_MAP = { "minutes" => "mins" }
      private_constant :INTERVAL_MAP

      def set_relative_time_interval(interval)
        select_kit = PageObjects::Components::SelectKit.new(".relative-time-intervals")
        select_kit.expand
        select_kit.select_row_by_value(INTERVAL_MAP[interval] || interval)
      end

      def click_save
        click_button("Set Timer")
      end
    end
  end
end
