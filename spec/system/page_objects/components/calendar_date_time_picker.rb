# frozen_string_literal: true

module PageObjects
  module Components
    class CalendarDateTimePicker < PageObjects::Components::Base
      def initialize(context)
        @context = context
      end

      def component
        find(@context)
      end

      def select_day(day_number)
        component.find("button.pika-button.pika-day[data-pika-day='#{day_number}']").click
      end

      def select_year(year)
        component
          .find(".pika-select-year", visible: false)
          .find("option[value='#{year}']")
          .select_option
      end

      def fill_time(time)
        component.find(".time-picker").fill_in(with: time)
      end
    end
  end
end
