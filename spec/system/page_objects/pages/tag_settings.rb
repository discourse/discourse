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
        find(".tag-settings__header h2")
      end

      def back_button
        find(".tag-settings__back-btn")
      end

      def nav_tabs
        find(".tag-settings__nav .nav-stacked")
      end

      def general_tab
        nav_tabs.find("li", text: I18n.t("js.tagging.general"))
      end

      def localizations_tab
        nav_tabs.find("li", text: I18n.t("js.tagging.localizations"))
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
        find(".tag-settings__footer button.btn-primary")
      end

      def delete_button
        find(".tag-settings__footer .btn-danger")
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
      def synonyms_section
        find(".tag-settings-synonyms")
      end

      def has_synonyms_section?
        has_css?(".tag-settings-synonyms")
      end

      def synonym_items
        all(".tag-settings-synonyms__item")
      end

      def has_synonym?(name)
        synonyms_section.has_css?(".tag-settings-synonyms__item", text: name)
      end

      def has_no_synonyms?
        has_css?(".tag-settings-synonyms__empty")
      end

      def synonyms_chooser
        PageObjects::Components::SelectKit.new(".tag-settings-synonyms__chooser .tag-chooser")
      end

      def add_synonym(name)
        synonyms_chooser.expand
        synonyms_chooser.search(name)
        synonyms_chooser.select_row_by_value(name)
        find(".tag-settings-synonyms__add .btn-primary").click
        self
      end

      def remove_synonym(name)
        item = synonyms_section.find(".tag-settings-synonyms__item", text: name)
        item.find(".btn-flat").click
        self
      end
    end
  end
end
