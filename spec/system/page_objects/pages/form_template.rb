# frozen_string_literal: true

module PageObjects
  module Pages
    class FormTemplate < PageObjects::Pages::Base
      def visit
        page.visit("/admin/customize/form-templates")
        self
      end

      def visit_new
        page.visit("/admin/customize/form-templates/new")
        self
      end

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
        find(".form-templates__table tbody tr td", text: name).present?
      end

      def has_no_form_template?(name)
        has_no_css?(".form-templates__table tbody tr td", text: name)
      end

      def has_category_in_template_row?(category_name)
        find(
          ".form-templates__table .categories .badge-category__name",
          text: category_name,
        ).present?
      end

      def has_template_structure?(structure)
        find("code", text: structure).present?
      end

      # Form Template new/edit form related
      def type_in_template_name(input)
        find(".form-templates__form-name-input").fill_in(with: input)
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
        find(".form-template-field__#{type}", visible: :all).present?
      end

      def has_input_field_with_name?(type, name)
        if type == "tag-chooser"
          # currently the tag chooser is rendered as a multi-select element
          find(".form-template-field__multi-select[name=#{name}]", visible: :all).present?
        elsif type == "upload"
          find(".form-template-field__#{type}[id=#{name}-uploader]", visible: :all).present?
        else
          find(".form-template-field__#{type}[name=#{name}]", visible: :all).present?
        end
      end

      def has_tag_chooser_tag?(tag)
        find("option[value=#{tag.name} i]", visible: :all).present?
      end

      def has_preview_modal?
        find(".form-template-form-preview-modal").present?
      end

      def has_no_preview_modal?
        has_no_css?(".form-template-form-preview-modal")
      end

      def has_validations_modal?
        find(".admin-form-template-validation-options-modal").present?
      end

      def has_name_value?(name)
        find(".form-templates__form-name-input").value == name
      end

      def has_save_button_with_state?(disabled:)
        find_button("Save", disabled:)
      end

      def has_preview_button_with_state?(disabled:)
        find_button("Preview", disabled:)
      end
    end
  end
end
