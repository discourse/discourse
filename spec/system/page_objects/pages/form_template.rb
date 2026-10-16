# frozen_string_literal: true

module PageObjects
  module Pages
    class FormTemplate < PageObjects::Pages::Base
      def visit
        browser_page
          .goto("/admin/customize/form-templates")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_new
        browser_page
          .goto("/admin/customize/form-templates/new")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      # Form Template Index
      def has_form_template_table?
        have_count(0).does_not_match?(
          browser_root.locator("table.form-templates__table").filter(visible: true),
        )
      end

      def click_view_form_template
        browser_root
          .locator(".form-templates__table tr:first-child .btn-view-template")
          .filter(visible: true)
          .click
      end

      def click_toggle_preview
        browser_root.locator(".d-toggle-switch .d-toggle-switch__checkbox-slider").click
        self
      end

      def has_form_template?(name)
        browser_root
          .locator(".form-templates__table tbody tr td")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(name))
          .present?
      end

      def has_no_form_template?(name)
        contain_text([browser_text_pattern(name)], useInnerText: true).does_not_match?(
          browser_root.locator(".form-templates__table tbody tr td").filter(visible: true),
        )
      end

      def has_category_in_template_row?(category_name)
        browser_root
          .locator(".form-templates__table .categories .badge-category__name")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(category_name))
          .present?
      end

      def has_template_structure?(structure)
        browser_root
          .locator("code")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(structure))
          .present?
      end

      # Form Template new/edit form related
      def type_in_template_name(input)
        browser_root.locator(".form-templates__form-name-input").filter(visible: true).fill(input)
        self
      end

      def click_save_button
        browser_root.locator(".form-templates__form .footer-buttons .btn-primary:enabled").click
      end

      def click_quick_insert(field_type)
        browser_root
          .locator(".form-templates__form .quick-insert-#{field_type}")
          .filter(visible: true)
          .click
      end

      def click_validations_button
        browser_root
          .locator(".form-templates__validations-modal-button")
          .filter(visible: true)
          .click
      end

      def click_preview_button
        browser_root.locator(".form-templates__preview-button:enabled").filter(visible: true).click
      end

      def has_input_field?(type)
        browser_root.locator(".form-template-field__#{type}").present?
      end

      def has_input_field_with_name?(type, name)
        if type == "tag-chooser"
          # currently the tag chooser is rendered as a multi-select element
          browser_root.locator(".form-template-field__multi-select[name=#{name}]").present?
        elsif type == "upload"
          browser_root.locator(".form-template-field__#{type}[id=#{name}-uploader]").present?
        else
          browser_root.locator(".form-template-field__#{type}[name=#{name}]").present?
        end
      end

      def has_tag_chooser_tag?(tag)
        display_value = tag.name.tr("-", " ").upcase
        browser_root.locator("option[value='#{display_value}']").present?
      end

      def has_preview_modal?
        browser_root.locator(".form-template-form-preview-modal").filter(visible: true).present?
      end

      def has_no_preview_modal?
        have_count(0).matches?(
          browser_root.locator(".form-template-form-preview-modal").filter(visible: true),
        )
      end

      def has_validations_modal?
        browser_root
          .locator(".admin-form-template-validation-options-modal")
          .filter(visible: true)
          .present?
      end

      def has_name_value?(name)
        browser_root
          .locator(".form-templates__form-name-input")
          .filter(visible: true)
          .input_value == name
      end

      def has_save_button_with_state?(disabled:)
        browser_root
          .get_by_role("button")
          .and(
            browser_root.locator("[id=#{"Save".to_s.to_json}], [name=#{"Save".to_s.to_json}]").or(
              browser_root.get_by_role("button", name: "Save"),
            ),
          )
          .filter(visible: true)
      end

      def has_preview_button_with_state?(disabled:)
        browser_root
          .get_by_role("button")
          .and(
            browser_root.locator(
              "[id=#{"Preview".to_s.to_json}], [name=#{"Preview".to_s.to_json}]",
            ).or(browser_root.get_by_role("button", name: "Preview")),
          )
          .filter(visible: true)
      end
    end
  end
end
