# frozen_string_literal: true

module PageObjects
  module Modals
    class PenalizeUser < PageObjects::Modals::Base
      def initialize(penalty_type)
        @penalty_type = penalty_type
      end

      def similar_users
        modal.all("table tbody tr td:nth-child(2)").map(&:text)
      end

      def modal
        find(".d-modal.#{@penalty_type}-user-modal")
      end

      def fill_in_suspend_reason(reason)
        find("input.suspend-reason").fill_in with: reason
      end

      def fill_in_silence_reason(reason)
        find("input.silence-reason").fill_in with: reason
      end

      def set_future_date(date)
        select = PageObjects::Components::SelectKit.new(".future-date-input details")
        select.expand
        select.select_row_by_value(date)
      end

      def perform
        find(".perform-penalize").click
      end

      def has_error_message?(message)
        expect(find("#modal-alert").text).to eq(message)
      end
    end
  end
end
