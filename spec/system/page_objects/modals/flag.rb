# frozen_string_literal: true

module PageObjects
  module Modals
    class Flag < PageObjects::Modals::Base
      BODY_SELECTOR = ".flag-modal-body"
      MODAL_SELECTOR = ".flag-modal"

      def choose_type(type)
        body.find("#radio_#{type}").click
      end

      def confirm_flag
        click_primary_button
      end

      def take_action(action)
        select_kit =
          PageObjects::Components::SelectKit.new(".d-modal__footer .reviewable-action-dropdown")
        select_kit.expand
        select_kit.select_row_by_value(action)
      end

      def fill_message(message)
        body.fill_in("message", with: message)
      end

      def check_confirmation
        body.check("confirmation")
      end

      def has_choices?(*choices)
        expect(body.all(".flag-action-type-details strong").map(&:text)).to eq(choices)
      end
    end
  end
end
