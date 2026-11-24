# frozen_string_literal: true

module PageObjects
  module Pages
    class TagSettings < PageObjects::Pages::Base
      SYNONYMS_CHOOSER = ".form-kit__field[data-name='synonyms'] .mini-tag-chooser"

      def visit(tag)
        page.visit "/tag/#{tag.slug_for_url}/#{tag.id}/edit/general"
        self
      end

      def visit_tab(tag, tab)
        page.visit "/tag/#{tag.slug_for_url}/#{tag.id}/edit/#{tab}"
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

      def remove_localization
        find(".form-kit__collection .btn-danger").click
        self
      end

      def has_localizations?
        has_css?(".form-kit__collection")
      end

      def has_no_localizations?
        has_no_css?(".form-kit__collection")
      end

      def name_input
        find("input[name='name']")
      end

      def slug_input
        find("input[name='slug']")
      end

      def description_textarea
        find(".form-kit__field[data-name='description'] textarea.d-editor-input")
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
        if synonyms_d_select?
          synonyms_field.has_css?(".d-select__chip", text: name)
        else
          synonym_items.include?(name)
        end
      end

      def has_no_synonyms?
        if synonyms_d_select?
          synonyms_field.has_no_css?(".d-select__chip")
        else
          header = synonyms_field.find(".multi-select-header")
          header["data-name"].to_s.strip.empty?
        end
      end

      def synonyms_chooser
        if synonyms_d_select?
          PageObjects::Components::UiKit::DSelect.at(SYNONYMS_CHOOSER)
        else
          PageObjects::Components::SelectKit.new(SYNONYMS_CHOOSER)
        end
      end

      def add_synonym(name)
        chooser = synonyms_chooser
        if chooser.is_a?(PageObjects::Components::UiKit::DSelect)
          # Opens through the query input: the trigger's centre can land on a chip's remove button.
          chooser.open
          chooser.search(name)
          chooser.select_name(name)
          chooser.close
        else
          chooser.expand
          chooser.search(name)
          chooser.select_row_by_name(name)
          chooser.collapse
        end
        self
      end

      def remove_synonym(name)
        chooser = synonyms_chooser
        if chooser.is_a?(PageObjects::Components::UiKit::DSelect)
          chooser.remove_name(name)
        else
          chooser.expand
          find(".select-kit-body .selected-content button[data-name='#{name}']").click
          chooser.collapse
        end
        self
      end

      # A DSelect driver when the new select controls render the tag switcher in the header, a
      # select-kit one otherwise.
      def tag_dropdown
        selector = ".tag-settings-title__dropdown .tag-dropdown"
        if has_css?(selector) && has_css?("#{selector}.d-select", wait: 0)
          PageObjects::Components::UiKit::DSelect.at(selector)
        else
          PageObjects::Components::SelectKit.new(selector)
        end
      end

      private

      def synonyms_d_select?
        has_css?(SYNONYMS_CHOOSER) && has_css?("#{SYNONYMS_CHOOSER}.d-select", wait: 0)
      end
    end
  end
end
