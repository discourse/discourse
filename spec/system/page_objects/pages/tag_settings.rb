# frozen_string_literal: true

module PageObjects
  module Pages
    class TagSettings < PageObjects::Pages::Base
      def visit(tag)
        browser_page
          .goto("/tag/#{tag.slug_for_url}/#{tag.id}/edit/general")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_tab(tag, tab)
        browser_page
          .goto("/tag/#{tag.slug_for_url}/#{tag.id}/edit/#{tab}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_tag_settings_page?
        have_count(0).does_not_match?(browser_root.locator(".tag-settings").filter(visible: true))
      end

      def has_no_tag_settings_page?
        have_count(0).matches?(browser_root.locator(".tag-settings").filter(visible: true))
      end

      def header
        browser_root.locator(".d-page-header__title").filter(visible: true)
      end

      def back_button
        browser_root
          .locator(".d-breadcrumbs a")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all[
          1
        ]
      end

      def nav_tabs
        browser_root.locator(".d-nav-submenu__tabs").filter(visible: true)
      end

      def general_tab
        nav_tabs
          .locator("li")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("js.tagging.settings.general")))
      end

      def localizations_tab
        nav_tabs
          .locator("li")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("js.tagging.settings.localizations")))
      end

      def click_general_tab
        general_tab.locator("a").filter(visible: true).click
        self
      end

      def click_localizations_tab
        localizations_tab.locator("a").filter(visible: true).click
        self
      end

      def remove_localization
        browser_root.locator(".form-kit__collection .btn-danger").filter(visible: true).click
        self
      end

      def has_localizations?
        have_count(0).does_not_match?(
          browser_root.locator(".form-kit__collection").filter(visible: true),
        )
      end

      def has_no_localizations?
        have_count(0).matches?(browser_root.locator(".form-kit__collection").filter(visible: true))
      end

      def name_input
        browser_root.locator("input[name='name']").filter(visible: true)
      end

      def slug_input
        browser_root.locator("input[name='slug']").filter(visible: true)
      end

      def description_textarea
        browser_root.locator(
          ".form-kit__field[data-name='description'] textarea.d-editor-input",
        ).filter(visible: true)
      end

      def fill_name(value)
        name_input.fill(value)
        self
      end

      def fill_slug(value)
        slug_input.fill(value)
        self
      end

      def fill_description(value)
        description_textarea.fill(value)
        self
      end

      def save_button
        browser_root.locator(".form-kit__actions button[type='submit']").filter(visible: true)
      end

      def delete_button
        browser_root.locator(".d-page-header__actions .btn-danger").filter(visible: true)
      end

      def click_save
        save_button.click
        self
      end

      def click_delete
        delete_button.click
        self
      end

      def click_back
        back_button.click
        self
      end

      def has_name_value?(value)
        name_input.input_value == value
      end

      def has_slug_value?(value)
        slug_input.input_value == value
      end

      def has_description_value?(value)
        description_textarea.input_value == value
      end

      # synonyms section
      def synonyms_field
        browser_root.locator(".form-kit__field[data-name='synonyms']").filter(visible: true)
      end

      def has_synonyms_section?
        have_count(0).does_not_match?(
          browser_root.locator(".form-kit__field[data-name='synonyms']").filter(visible: true),
        )
      end

      def formatted_synonyms
        synonyms_field.locator(".formatted-selection").filter(visible: true).inner_text.strip
      end

      def synonym_items
        formatted_synonyms.split(", ")
      end

      def has_synonym?(name)
        synonym_items.include?(name)
      end

      def has_no_synonyms?
        header = synonyms_field.locator(".multi-select-header").filter(visible: true)
        header.get_attribute("data-name").to_s.strip.empty?
      end

      def synonyms_chooser
        PageObjects::Components::SelectKit.new(
          ".form-kit__field[data-name='synonyms'] .mini-tag-chooser",
        )
      end

      def add_synonym(name)
        synonyms_chooser.expand
        synonyms_chooser.search(name)
        synonyms_chooser.select_row_by_name(name)
        synonyms_chooser.collapse
        self
      end

      def remove_synonym(name)
        synonyms_chooser.expand
        browser_root
          .locator(".select-kit-body .selected-content button[data-name='#{name}']")
          .filter(visible: true)
          .click
        synonyms_chooser.collapse
        self
      end
    end
  end
end
