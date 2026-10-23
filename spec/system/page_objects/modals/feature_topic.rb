# frozen_string_literal: true

module PageObjects
  module Modals
    class FeatureTopic < Base
      MODAL_SELECTOR = ".feature-topic"

      def select_custom_date(day:, globally: false)
        selector =
          PageObjects::Components::SelectKit.new(
            "#{section_selector(globally:)} .future-date-input-selector",
          )
        selector.expand
        selector.select_row_by_value("custom")
        calendar =
          PageObjects::Components::PikadayCalendar.new(
            "#{section_selector(globally:)} .date-picker",
          )
        calendar.open_calendar
        calendar.select_day(day)
      end

      def set_time(time:, globally: false)
        input = find("#{section_selector(globally:)} .time-input")
        input.click
        input.set(time)
      end

      def has_focused_time?(time:, globally: false)
        has_css?("#{section_selector(globally:)} .time-input:focus") { |input| input.value == time }
      end

      def pin(globally: false)
        find("#{section_selector(globally:)} .btn-primary").click
      end

      def has_pin_expiry?(date)
        has_css?("#{MODAL_SELECTOR} .feature-section strong", text: date)
      end

      def unpin
        within(MODAL_SELECTOR) { click_button(I18n.t("js.topic.feature.unpin")) }
      end

      private

      def section_selector(globally:)
        "#{MODAL_SELECTOR} form.feature-section:#{globally ? "last" : "first"}-of-type"
      end
    end
  end
end
