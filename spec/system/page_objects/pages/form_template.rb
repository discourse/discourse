# frozen_string_literal: true

module PageObjects
  module Pages
    class FormTemplate < PageObjects::Pages::Base
      # Form Template Index
      def has_form_template_table?
        page.has_selector?("table.form-templates__table")
      end

      def click_view_form_template
        find(".form-templates__table tr:first-child .btn-view-template").click
      end

      def click_toggle_preview
        find(".d-toggle-switch .d-toggle-switch__checkbox-slider", visible: false).click
        self
      end

      def has_form_template?(name)
        has_css?(".form-templates__table tbody tr td", text: name)
      end

      def has_category_in_template_row?(category_name)
        has_css?(".form-templates__table tbody tr td", text: category_name)
      end

      def has_template_structure?(structure)
        has_css?("code", text: structure)
      end

      # Form Template new/edit form related
      def type_in_template_name(input)
        find(".form-templates__form-name-input").send_keys(input)
        self
      end

      def click_save_button
        find(".form-templates__form .footer-buttons .btn-primary:enabled", visible: :all).click
      end

      def click_quick_insert(field_type)
        find(".form-templates__form .quick-insert-#{field_type}").click
      end

      def click_validations_button
        find(".form-templates__validations-modal-button").click
      end

      def click_preview_button
        find(".form-templates__preview-button:enabled").click
      end

      def has_input_field?(type)
        has_css?(".form-template-field__#{type}")
      end

      def has_preview_modal?
        has_css?(".form-template-form-preview-modal")
      end

      def has_validations_modal?
        has_css?(".admin-form-template-validation-options-modal")
      end

      def has_name_value?(name)
        find(".form-templates__form-name-input").value == name
      end

      def has_save_button_with_state?(state)
        has_button?("Save", disabled: state)
      end

      def has_preview_button_with_state?(state)
        has_button?("Preview", disabled: state)
      end
    end
  end
end
