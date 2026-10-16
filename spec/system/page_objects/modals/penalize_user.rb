# frozen_string_literal: true

module PageObjects
  module Modals
    class PenalizeUser < PageObjects::Modals::Base
      def initialize(penalty_type)
        @penalty_type = penalty_type
      end

      def similar_users
        modal
          .locator("table tbody tr td:nth-child(2)")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |element| element.inner_text.strip }
      end

      def select_similar_user(username)
        modal
          .locator("table tbody tr")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(username))
          .locator("input[type=checkbox]")
          .check
      end

      def modal
        browser_root.locator(".d-modal.#{@penalty_type}-user-modal").filter(visible: true)
      end

      def suspend(reason, date: "tomorrow")
        fill_in_suspend_reason(reason)
        set_future_date(date)
        perform
      end

      def fill_in_suspend_reason(reason)
        browser_root.locator("input.suspend-reason").filter(visible: true).fill(reason)
      end

      def fill_in_silence_reason(reason)
        browser_root.locator("input.silence-reason").filter(visible: true).fill(reason)
      end

      def set_future_date(date)
        select = PageObjects::Components::SelectKit.new(".future-date-input details")
        select.expand
        select.select_row_by_value(date)
      end

      def perform
        browser_root.locator(".perform-penalize").filter(visible: true).click
      end

      def has_error_message?(message)
        expect(browser_root.locator("#modal-alert").filter(visible: true).inner_text.strip).to eq(
          message,
        )
      end
    end
  end
end
