# frozen_string_literal: true

module PageObjects
  module Pages
    class TagSettings < PageObjects::Pages::Base
      def visit(tag)
        page.visit "/tag/#{tag.slug}/#{tag.id}/edit/general"
        self
      end

      def visit_tab(tag, tab)
        page.visit "/tag/#{tag.slug}/#{tag.id}/edit/#{tab}"
        self
      end

      def has_tag_settings_page?
        has_css?(".tag-settings")
      end

      def has_no_tag_settings_page?
        has_no_css?(".tag-settings")
      end

      def header
        find(".d-page-header__title")
      end

      def back_button
        all(".d-breadcrumbs a")[1]
      end

      def nav_tabs
        find(".d-nav-submenu__tabs")
      end

      def general_tab
        nav_tabs.find("li", text: I18n.t("js.tagging.settings.general"))
      end

      def localizations_tab
        nav_tabs.find("li", text: I18n.t("js.tagging.settings.localizations"))
      end

      def click_general_tab
        general_tab.find("a").click
        self
      end

      def click_localizations_tab
        localizations_tab.find("a").click
        self
      end

      def name_input
        find("input[name='name']")
      end

      def slug_input
        find("input[name='slug']")
      end

      def description_textarea
        find("textarea[name='description']")
      end

      def fill_name(value)
        name_input.fill_in(with: value)
        self
      end

      def fill_slug(value)
        slug_input.fill_in(with: value)
        self
      end

      def fill_description(value)
        description_textarea.fill_in(with: value)
        self
      end

      def save_button
        find(".form-kit__actions button[type='submit']")
      end

      def delete_button
        find(".d-page-header__actions .btn-danger")
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
        name_input.value == value
      end

      def has_slug_value?(value)
        slug_input.value == value
      end

      def has_description_value?(value)
        description_textarea.value == value
      end

      # synonyms section
      def synonyms_field
        find(".form-kit__field[data-name='synonyms']")
      end

      def has_synonyms_section?
        has_css?(".form-kit__field[data-name='synonyms']")
      end

      def formatted_synonyms
        synonyms_field.find(".formatted-selection").text
      end

      def synonym_items
        formatted_synonyms.split(", ")
      end

      def has_synonym?(name)
        synonym_items.include?(name)
      end

      def has_no_synonyms?
        header = synonyms_field.find(".multi-select-header")
        header["data-name"].to_s.strip.empty?
      end

      def synonyms_chooser
        PageObjects::Components::SelectKit.new(
          ".form-kit__field[data-name='synonyms'] .mini-tag-chooser",
        )
      end

      def add_synonym(name)
        synonyms_chooser.expand
        synonyms_chooser.search(name)
        synonyms_chooser.select_row_by_value(name)
        self
      end

      def remove_synonym(name)
        synonyms_chooser.expand
        find(".select-kit-body .selected-content button[data-name='#{name}']").click
        synonyms_chooser.collapse
        self
      end
    end
  end
end
