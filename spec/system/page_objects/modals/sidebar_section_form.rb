# frozen_string_literal: true

module PageObjects
  module Modals
    class SidebarSectionForm < PageObjects::Modals::Base
      def fill_name(name)
        fill_in "section-name", with: name
      end

      def fill_link(name, url, icon = "link")
        fill_in("link-name", with: name, match: :first)
        fill_in("link-url", with: url, match: :first)
        icon_picker = first_link_icon_picker
        icon_picker.expand
        icon_picker.filter(icon)
        icon_picker.select_icon(icon)
      end

      def fill_last_link(name, url, icon = "link")
        primary_links_wrapper
          .all(".sidebar-section-form-link")
          .last
          .then do |link_row|
            link_row.fill_in("link-name", with: name)
            link_row.fill_in("link-url", with: url)

            icon_picker = PageObjects::Components::DIconGridPicker.new(link_row)
            icon_picker.expand
            icon_picker.filter(icon)
            icon_picker.select_icon(icon)
          end
      end

      def first_link_icon_picker
        PageObjects::Components::DIconGridPicker.new(
          find(".sidebar-section-form-link", match: :first),
        )
      end

      def add_link
        all(".sidebar-section-form-modal .add-link").first.click
        self
      end

      def mark_as_public
        find(".d-modal .mark-public").click
      end

      def remove_last_link
        all(".delete-link").last.click
      end

      def add_section_title_translation
        find(".add-localization").click
      end

      def add_section_localization(title)
        add_section_title_translation
        all(section_title_translation_locale_selector)
          .last
          .find("option[value='ja']", visible: :all)
          .select_option
        all(
          "input[aria-label='#{I18n.t("js.sidebar.sections.custom.localizations.title_label")}']",
        ).last.fill_in(with: title)
      end

      def add_first_link_localization(name)
        find(".add-link-localization", match: :first).click
        all("select[aria-label='#{I18n.t("js.sidebar.sections.custom.localizations.locale")}']")
          .last
          .find("option[value='ja']")
          .select_option
        all(
          "input[aria-label='#{I18n.t("js.sidebar.sections.custom.localizations.link_label")}']",
        ).last.fill_in(with: name)
      end

      def add_last_link_localization(name)
        primary_links_wrapper
          .all(".sidebar-section-form-link-wrapper")
          .last
          .find(".add-link-localization")
          .click
        all("select[aria-label='#{I18n.t("js.sidebar.sections.custom.localizations.locale")}']")
          .last
          .find("option[value='ja']")
          .select_option
        all(
          "input[aria-label='#{I18n.t("js.sidebar.sections.custom.localizations.link_label")}']",
        ).last.fill_in(with: name)
      end

      def delete
        find("#delete-section").click
      end

      def confirm_delete
        find(".dialog-container .btn-danger").click
        closed?
      end

      def confirm_update
        find(".dialog-container .btn-primary").click
        closed?
      end

      def reset
        find(".reset-link").click
        find(".dialog-footer .btn-primary").click
        closed?
        self
      end

      def save
        find("#save-section").click
        self
      end

      def visible?
        page.has_css?(".sidebar-section-form-modal")
      end

      def closed?
        page.has_no_css?(".sidebar-section-form-modal")
      end

      def has_disabled_save?
        find_button("Save", disabled: true)
      end

      def has_enabled_save?
        find_button("Save", disabled: false)
      end

      def has_localization_controls?
        page.has_css?(".sidebar-section-form__localization-row") &&
          page.has_css?(".add-localization") && page.has_css?(".add-link-localization")
      end

      def has_no_localization_controls?
        page.has_no_css?(".sidebar-section-form__localization-row") &&
          page.has_no_css?(".add-localization") && page.has_no_css?(".add-link-localization")
      end

      def has_locale_option?(locale)
        page.has_css?(
          "select[aria-label='#{I18n.t("js.sidebar.sections.custom.localizations.locale")}'] option[value='#{locale}']",
          visible: :all,
        )
      end

      def has_no_locale_option?(locale)
        page.has_no_css?(
          "select[aria-label='#{I18n.t("js.sidebar.sections.custom.localizations.locale")}'] option[value='#{locale}']",
          visible: :all,
        )
      end

      def section_title_translation_locales
        all(section_title_translation_locale_selector).map(&:value)
      end

      def has_disabled_section_title_translation_locale?(row, locale)
        all(section_title_translation_locale_selector)[row].has_css?(
          "option[value='#{locale}'][disabled]",
          visible: :all,
        )
      end

      def has_no_add_section_title_translation?
        page.has_no_css?(".add-localization")
      end

      def has_section_links_label?
        page.has_css?(".sidebar-section-form__links-label", text: "Section links")
      end

      def has_section_name?(name)
        page.has_field?("section-name", with: name)
      end

      def has_first_link_name?(name)
        page.has_field?("link-name", with: name, match: :first)
      end

      def topics_link
        find(".draggable[data-link-name='Topics']")
      end

      def review_link
        find(".draggable[data-link-name='Review']")
      end

      private

      def section_title_translation_locale_selector
        ".sidebar-section-form > .sidebar-section-form__localizations select[aria-label='#{I18n.t("js.sidebar.sections.custom.localizations.locale")}']"
      end

      def primary_links_wrapper
        find(".sidebar-section-form__links-wrapper")
      end
    end
  end
end
