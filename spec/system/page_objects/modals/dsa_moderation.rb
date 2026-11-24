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

      def has_no_classification_help?(text)
        has_no_css?("[role='tooltip']", text: text)
      end

      def has_dsa_learn_more_link?(url)
        has_css?("[role='tooltip'] a[href='#{url}'][target='_blank']", text: "Learn more…")
      end

      def click_category_help
        within(full_modal_selector) { find("[data-name='category'] .form-kit__tooltip").click }
      end

      def hover_category_help
        within(full_modal_selector) { find("[data-name='category'] .form-kit__tooltip").hover }
      end

      def open_rule_menu
        return rule_select.open if SiteSetting.enable_new_select_controls

        within(full_modal_selector) do
          find("[data-name='community_rule'] .form-kit__control-menu-trigger").click
        end
      end

      def close_rule_menu
        page.send_keys(:escape)
      end

      def select_rule(ground)
        return rule_select.select_name(ground) if SiteSetting.enable_new_select_controls

        open_rule_menu
        find(".dsa-classification-option", text: ground).click
      end

      def has_no_classification_menu?
        return false if SiteSetting.enable_new_select_controls && !rule_select.has_no_listbox?

        has_no_css?(".dsa-classification-option")
      end

      def has_rule_option?(ground, explanation:)
        if SiteSetting.enable_new_select_controls
          return(
            has_css?(
              rule_select.in_panel("[role='option'][data-name='#{ground}']"),
              text: "#{ground} #{explanation}",
              exact_text: true,
              normalize_ws: true,
            )
          )
        end

        has_button?("#{ground} #{explanation}", exact: true, normalize_ws: true)
      end

      def select_category(category)
        within(full_modal_selector) do
          find("[data-name='category'] .form-kit__control-menu-trigger").click
        end
        find(".dsa-classification-option", text: category, exact_text: true).click
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

      def has_disabled_button?(label)
        within(full_modal_selector) { has_button?(label, exact: true, disabled: true) }
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

      def has_field_hint?(field, text)
        has_css?(
          "#{full_modal_selector} [data-name='#{field}'] .form-kit__container-help-text",
          text:,
        )
      end

      def has_no_field_hint?(field)
        has_no_css?("#{full_modal_selector} [data-name='#{field}'] .form-kit__container-help-text")
      end

      def has_selected_rule?(ground)
        return rule_select.has_selected_name?(ground) if SiteSetting.enable_new_select_controls

        has_css?(
          "#{full_modal_selector} [data-name='community_rule'] .d-button-label",
          text: ground,
          exact_text: true,
        )
      end

      def has_no_selected_rule?
        if SiteSetting.enable_new_select_controls
          return(
            has_css?(
              "#{full_modal_selector} [data-name='community_rule'] [role='combobox']",
            ) { |input| input.value.empty? }
          )
        end

        has_selected_rule?(I18n.t("js.dsa_statements.rule_prompt"))
      end

      # The new combobox exposes the held rule as its value, so it needs no hidden label.
      def has_accessible_selection?(field, label)
        if field == "community_rule" && SiteSetting.enable_new_select_controls
          return(
            has_css?(
              "#{full_modal_selector} [data-name='community_rule'] [role='combobox']",
            ) { |input| input.value == label }
          )
        end

        has_css?(
          "#{full_modal_selector} [data-name='#{field}'] .form-kit__control-menu-trigger",
        ) do |trigger|
          trigger.evaluate_script(
            "this.labels[0]?.querySelector('.dsa-classification-selected-label')?.textContent.trim()",
          ) == label
        end
      end

      def has_selected_category?(category)
        has_css?(
          "#{full_modal_selector} [data-name='category'] .d-button-label",
          text: category,
          exact_text: true,
        )
      end

      def has_focused_step?(label)
        has_css?("#{full_modal_selector} [aria-current='step']:focus", text: label)
      end

      def has_accessible_field_description?(field, text, invalid: false)
        invalid_selector = invalid ? "[aria-invalid='true']" : ":not([aria-invalid='true'])"
        has_css?(
          "#{full_modal_selector} [data-name='#{field}'] #{field_control(field)}#{invalid_selector}",
        ) do |trigger|
          trigger.evaluate_script(
            "this.ariaDescribedByElements?.some((element) => element.textContent.trim() === arguments[0])",
            text,
          )
        end
      end

      private

      def field_control(field)
        if field == "community_rule" && SiteSetting.enable_new_select_controls
          "[role='combobox']"
        else
          ".form-kit__control-menu-trigger"
        end
      end

      def rule_select
        PageObjects::Components::UiKit::DSelect.at(
          "#{full_modal_selector} [data-name='community_rule'] .d-select",
        )
      end
    end
  end
end
