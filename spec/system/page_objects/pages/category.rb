# frozen_string_literal: true

module PageObjects
  module Pages
    class Category < PageObjects::Pages::Base
      # keeping the various category related features combined for now

      def visit(category)
        page.visit("/c/#{category.id}")
        self
      end

      def visit_settings(category)
        page.visit("/c/#{category.slug}/edit/settings")
        self
      end

      def visit_edit_template(category)
        page.visit("/c/#{category.slug}/edit/topic-template")
        self
      end

      def back_to_category
        find(".edit-category-title-bar span", text: "Back to category").click
        self
      end

      def save_settings
        find("#save-category").click
        self
      end

      def toggle_setting(setting, text = "")
        find(".edit-category-tab .#{setting} label.checkbox-label", text: text).click
        self
      end

      # Edit Category Page
      def has_form_template_enabled?
        find(".d-toggle-switch .toggle-template-type", visible: false)["aria-checked"] == "true"
      end

      def has_d_editor?
        page.has_selector?(".d-editor")
      end

      def has_selected_template?(template_name)
        find(".select-category-template .select-kit-header")["data-name"] == template_name
      end

      def toggle_form_templates
        find(".d-toggle-switch .d-toggle-switch__checkbox-slider").click
        self
      end

      def select_form_template(template_name)
        find(".select-category-template").click
        find(".select-kit-collection .select-kit-row", text: template_name).click
        find(".select-category-template").click
      end
    end
  end
end
