# frozen_string_literal: true

module PageObjects
  module Modals
    class RecalculateScoresForm < PageObjects::Modals::Base
      def update_range_dropdown
        PageObjects::Components::SelectKit.new("#update-range")
      end

      def select_update_range(value: nil)
        update_range_dropdown.expand
        update_range_dropdown.select_row_by_value(value)
      end

      def fill_since_date(since)
        find("#custom-from-date").fill_in(with: since)
      end

      def date_range
        find(".recalculate-modal__date-range")
      end

      def custom_since_date
        find("#custom-from-date input")
      end

      def status
        find(".recalculate-modal__status")
      end

      def remaining
        find(".recalculate-modal__footer-text")
      end

      def apply
        find("#apply-section")
      end
    end
  end
end
