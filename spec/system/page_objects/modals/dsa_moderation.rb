# frozen_string_literal: true

module PageObjects
  module Modals
    class DsaModeration < Base
      MODAL_SELECTOR =
        ":is(.dsa-moderation-action, .suspend-user-modal, .silence-user-modal, .revise-and-reject-reviewable)"

      def initialize
        super(modal_selector: MODAL_SELECTOR)
      end

      def select_rule(ground)
        within(full_modal_selector) { select(ground, from: "Community rule") }
      end

      def select_category(category)
        within(full_modal_selector) { select(category, from: "Category") }
      end

      def continue
        within(full_modal_selector) { click_button("Continue", exact: true) }
      end

      def has_disabled_continue?
        within(full_modal_selector) { has_button?("Continue", exact: true, disabled: true) }
      end

      def back
        within(full_modal_selector) { click_button("Back", exact: true) }
      end

      def has_cancel_button?
        within(full_modal_selector) { has_button?("Cancel", exact: true) }
      end

      def has_no_cancel_button?
        within(full_modal_selector) { has_no_button?("Cancel", exact: true) }
      end

      def confirm(label)
        within(full_modal_selector) { click_button(label, exact: true) }
      end

      def has_action_title?(title)
        has_css?("#{full_modal_selector} .d-modal__title-text", text: title, exact_text: true)
      end

      def has_single_classification_step?
        has_css?(
          "#{full_modal_selector} .dsa-moderation-steps li:only-child[aria-current='step']",
          text: I18n.t("js.dsa_statements.title"),
          count: 1,
        )
      end

      def has_classification?
        has_css?("#{full_modal_selector} .dsa-moderation-details")
      end

      def has_confirmation_prompt?(message)
        within(full_modal_selector) { has_text?(message) }
      end

      def has_selected_category?(category)
        within(full_modal_selector) { has_select?("Category", selected: category) }
      end

      def has_focused_step?(label)
        has_css?("#{full_modal_selector} [aria-current='step']:focus", text: label)
      end

      def has_required_errors?
        has_css?("#{full_modal_selector} .form-kit__errors", text: "Required")
      end
    end
  end
end
