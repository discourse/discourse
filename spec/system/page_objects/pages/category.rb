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
      def has_template_value?(value)
        find(".select-category-template", text: value).present?
      end

      def has_d_editor?
        page.has_selector?(".d-editor")
      end

      def has_template_preview?(template_content)
        find("code.language-yaml", text: template_content).present?
      end

      def toggle_form_template(template_name)
        find(".select-category-template").click
        find(".select-kit-collection .select-kit-row", text: template_name).click
      end
    end
  end
end
