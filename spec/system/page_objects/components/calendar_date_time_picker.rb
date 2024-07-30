# frozen_string_literal: true

module PageObjects
  module Components
    class CalendarDateTimePicker < PageObjects::Components::Base
      delegate :select_day, :select_year, to: :@pikaday_calendar

      def initialize(context)
        @context = context
        @pikaday_calendar = PageObjects::Components::PikadayCalendar.new(context)
      end

      def component
        find(@context)
      end

      def fill_time(time)
        component.find(".time-picker").fill_in(with: time)
      end
    end
  end
end
