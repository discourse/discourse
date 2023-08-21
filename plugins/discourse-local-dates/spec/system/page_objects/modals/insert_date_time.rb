# frozen_string_literal: true

module PageObjects
  module Modals
    class InsertDateTime < PageObjects::Modals::Base
      MODAL_CSS_CLASS = ".discourse-local-dates-create-modal"

      def calendar_date_time_picker
        @calendar_date_time_picker ||=
          PageObjects::Components::CalendarDateTimePicker.new(MODAL_CSS_CLASS)
      end

      def select_to
        find(".date-time-control.to").click
      end

      def select_from
        find(".date-time-control.from").click
      end

      def delete_to
        find(".delete-to-date").click
      end
    end
  end
end
