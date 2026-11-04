# frozen_string_literal: true

module PageObjects
  module Modals
    class DsaModeration < Base
      MODAL_SELECTOR =
        ":is(.dsa-moderation-action, .suspend-user-modal, .silence-user-modal, .revise-and-reject-reviewable)"

      def initialize
        super(modal_selector: MODAL_SELECTOR)
      end

      def open_dsa_help
        within(full_modal_selector) { find(".dsa-moderation-help").hover }
      end

      def has_classification_help?(text)
        has_css?("[role='tooltip']", text: text)
      end

      def has_dsa_learn_more_link?(url)
        has_css?("[role='tooltip'] a[href='#{url}'][target='_blank']", text: "Learn more…")
      end

      def open_rule_menu
        within(full_modal_selector) do
          find("[data-name='community_rule'] .form-kit__control-menu-trigger").click
        end
      end

      def close_rule_menu
        page.send_keys(:escape)
      end

      def select_rule(ground)
        open_rule_menu
        find(".form-kit__control-menu-content .btn", text: ground).click
      end

      def has_no_rule_menu?
        has_no_css?(".dsa-community-rules")
      end

      def has_rule_option?(ground, explanation:)
        has_button?("#{ground} #{explanation}", exact: true, normalize_ws: true)
      end

      def select_category(category)
        within(full_modal_selector) { select(category, from: "Category") }
      end

      def continue
        within(full_modal_selector) { click_button("Continue", exact: true) }
      end

      def click_previous_step
        within(full_modal_selector) { find(".dsa-moderation-steps__back").click }
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

      def has_steps?(*labels)
        has_css?("#{full_modal_selector} .dsa-moderation-steps li", count: labels.size) &&
          labels.each_with_index.all? do |label, index|
            has_css?(
              "#{full_modal_selector} .dsa-moderation-steps li:nth-child(#{index + 1})",
              text: label,
            )
          end
      end

      def has_action_title?(title)
        has_css?("#{full_modal_selector} .d-modal__title-text", text: title, exact_text: true)
      end

      def has_classification?
        has_css?("#{full_modal_selector} .dsa-moderation-details")
      end

      def has_confirmation_prompt?(message)
        within(full_modal_selector) { has_text?(message, normalize_ws: true) }
      end

      def has_selected_rule?(ground)
        has_css?(
          "#{full_modal_selector} [data-name='community_rule'] .d-button-label",
          text: ground,
          exact_text: true,
        )
      end

      def has_accessible_rule_description?(ground)
        has_css?("#{full_modal_selector} .dsa-community-rule-trigger") do |trigger|
          trigger["aria-description"] == ground
        end
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
