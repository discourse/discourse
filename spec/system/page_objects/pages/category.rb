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

      def visit_edit_localizations(category)
        page.visit("/c/#{category.slug}/edit/localizations")
      end

      def visit_categories
        page.visit("/categories")
        self
      end

      def visit_new_category
        page.visit("/new-category")
        self
      end

      def visit_security(category)
        page.visit("/c/#{category.slug}/edit/security")
        self
      end

      def visit_images(category)
        page.visit("/c/#{category.slug}/edit/images")
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
        find(".edit-category-tab .#{setting} label.checkbox-label", text: text, visible: :all).click
        self
      end

      # Edit Category Page
      def has_form_template_enabled?
        find(".d-toggle-switch .toggle-template-type", visible: false)["aria-checked"] == "true"
      end

      D_EDITOR_SELECTOR = ".d-editor"

      def has_d_editor?
        page.has_selector?(D_EDITOR_SELECTOR)
      end

      def has_no_d_editor?
        page.has_no_selector?(D_EDITOR_SELECTOR)
      end

      def has_selected_template?(template_name)
        has_css?(".select-category-template .select-kit-header[data-name='#{template_name}']")
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

      def new_topic_button
        find("#create-topic")
      end

      CATEGORY_NAVIGATION_NEW_NAV_ITEM_SELECTOR = ".category-navigation .nav-item_new"

      def has_no_new_topics?
        page.has_no_css?(CATEGORY_NAVIGATION_NEW_NAV_ITEM_SELECTOR)
      end

      def has_new_topics?
        page.has_css?(CATEGORY_NAVIGATION_NEW_NAV_ITEM_SELECTOR)
      end

      def click_new
        page.find(CATEGORY_NAVIGATION_NEW_NAV_ITEM_SELECTOR).click
      end

      def has_public_access_message?
        page.has_content?(I18n.t("js.category.permissions.everyone_has_access"))
      end

      def has_no_public_access_message?
        page.has_no_content?(I18n.t("js.category.permissions.everyone_has_access"))
      end

      def has_setting_tab?(tab_name)
        tab_css = ".edit-category-#{tab_name}"
        page.has_css?(tab_css)
      end

      def has_no_setting_tab?(tab_name)
        tab_css = ".edit-category-#{tab_name}"
        page.has_no_css?(tab_css)
      end
    end
  end
end
