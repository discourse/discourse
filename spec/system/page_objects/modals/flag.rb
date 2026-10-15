# frozen_string_literal: true

module PageObjects
  module Modals
    class Flag < PageObjects::Modals::Base
      BODY_SELECTOR = ".flag-modal-body"
      MODAL_SELECTOR = ".flag-modal"

      def choose_type(type)
        body.locator("#radio_#{type}").filter(visible: true).click
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
        body
          .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
          .and(
            body.locator("[id=#{"message".to_s.to_json}], [name=#{"message".to_s.to_json}]").or(
              body.get_by_label("message", exact: true),
            ),
          )
          .filter(visible: true)
          .fill(message)
      end

      def check_confirmation
        body.locator("#confirmation, input[name=confirmation]").check
      end

      def has_choices?(*choices)
        expect(
          body
            .locator(".flag-action-type-details strong")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all
            .map { |element| element.inner_text.strip },
        ).to eq(choices)
      end
    end
  end
end
