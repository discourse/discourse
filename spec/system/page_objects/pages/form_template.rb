# frozen_string_literal: true

module PageObjects
  module Pages
    class FormTemplate < PageObjects::Pages::Base
      # Form Template Index
      def has_form_template_table?
        page.has_selector?("table.form-templates--table")
      end

      def click_view_form_template
        find(".form-templates--table tr:first-child .btn-view-template").click
      end

      def has_form_template?(name)
        find(".form-templates--table tbody tr td", text: name).present?
      end

      def has_template_structure?(structure)
        find("code", text: structure).present?
      end

      # Form Template new/edit form related
      def type_in_template_name(input)
        find(".form-templates--form-name-input").send_keys(input)
        self
      end

      def click_save_button
        find(".form-templates--form .footer-buttons .btn-primary").click
      end

      def click_quick_insert(field_type)
        find(".form-templates--form .quick-insert-#{field_type}").click
      end

      def has_name_value?(name)
        find(".form-templates--form-name-input").value == name
      end
    end
  end
end
