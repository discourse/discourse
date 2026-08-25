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

      def open_translations
        find(".sidebar-section-form__manage-translations").click
        self
      end

      def close_translations
        find(".sidebar-section-translations__back").click
        self
      end

      def add_language(locale)
        find(".sidebar-section-translations__add-language").click
        PageObjects::Components::DSelect.new(translation_language_selects.last).select(locale)
      end

      def remove_language(locale)
        translation_language(locale).find(".sidebar-section-translations__remove-language").click
      end

      def fill_translation(locale, source, value)
        translation_language(locale)
          .find(".sidebar-section-translations__row", text: source)
          .find("input")
          .fill_in(with: value)
      end

      def delete
        find("#delete-section").click
      end

      def confirm_delete
        PageObjects::Components::Dialog.new.click_danger
        closed?
      end

      def confirm_update
        confirm_dialog
        closed?
      end

      def confirm_dialog
        dialog = PageObjects::Components::Dialog.new
        dialog.click_yes
        dialog.closed?
        self
      end

      def reset
        find(".reset-link").click
        PageObjects::Components::Dialog.new.click_yes
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
        page.has_css?(".sidebar-section-form__manage-translations")
      end

      def has_no_localization_controls?
        page.has_no_css?(".sidebar-section-form__manage-translations")
      end

      def has_locale_option?(locale)
        page.has_css?(
          ".sidebar-section-translations__language-select option[value='#{locale}']",
          visible: :all,
        )
      end

      def has_no_locale_option?(locale)
        page.has_no_css?(
          ".sidebar-section-translations__language-select option[value='#{locale}']",
          visible: :all,
        )
      end

      def has_translation_languages?(count)
        page.has_css?(".sidebar-section-translations__language", count:)
      end

      def has_translation_row?(locale, source)
        page.has_css?(translation_row_selector(locale), text: source)
      end

      def has_no_translation_row?(locale, source)
        page.has_no_css?(translation_row_selector(locale), text: source)
      end

      def has_translation_language?(locale)
        page.has_css?(translation_language_selector(locale))
      end

      def has_selected_translation_language?(locale)
        page.has_css?(
          "#{translation_language_selector(locale)} " \
            ".sidebar-section-translations__language-select option[value='#{locale}']:checked",
          visible: :all,
        )
      end

      def has_no_translation_language?(locale)
        page.has_no_css?(translation_language_selector(locale))
      end

      def has_disabled_translation_locale?(locale, disabled)
        translation_language(locale).has_css?(
          ".sidebar-section-translations__language-select option[value='#{disabled}'][disabled]",
          visible: :all,
        )
      end

      def has_no_add_language?
        page.has_no_css?(".sidebar-section-translations__add-language")
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

      # Driven by the keyboard rather than clicked: the reorder control exists
      # because a drag has no keyboard path, so the spec has to go through the
      # keyboard to be testing the thing it was added for. The chord is the
      # single-press keyboard path; the menu behind Enter is the other one.
      def move_link_up(name)
        link_handle(name).send_keys(%i[alt up])
      end

      def move_link_down(name)
        link_handle(name).send_keys(%i[alt down])
      end

      # Presses whatever the previous move left focused, rather than looking the
      # handle up again. Finding it by name would pass even if focus had been
      # lost, which is most of what there is to get wrong here.
      def press_focused_link_move_down
        page.driver.with_playwright_page { |pw_page| pw_page.keyboard.press("Alt+ArrowDown") }
      end

      # Opens the focused link's move menu, for the path that does not depend
      # on a modifier chord reaching the page.
      def open_focused_link_menu
        page.driver.with_playwright_page { |pw_page| pw_page.keyboard.press("Enter") }
      end

      # The link whose row currently holds focus. The row is the cursor's item,
      # so this is what says focus survived a move; the handle inside it is a
      # pointer affordance and never takes focus from the keyboard.
      def focused_link_name
        page.evaluate_script("document.activeElement?.dataset?.linkName")
      end

      def link_handle(name)
        find("button[aria-label='Reorder #{name}']")
      end

      # Read from the name inputs, not from the drag handles, so it reports the
      # order on a touch screen too — where no handle renders. Scoped away from
      # the secondary list, which renders in a wrapper of its own.
      def link_names
        all(".sidebar-section-form__links-wrapper:not(.--secondary) input[name='link-name']").map(
          &:value
        )
      end

      def has_source_language?(locale)
        page.has_css?(
          ".sidebar-section-form__source-locale-select option[value='#{locale}']:checked",
          visible: :all,
        )
      end

      def has_no_source_language_control?
        page.has_no_css?(".sidebar-section-form__source-locale")
      end

      def select_source_language(locale)
        PageObjects::Components::DSelect.new(".sidebar-section-form__source-locale-select").select(
          locale,
        )
      end

      private

      def translation_language(locale)
        find(translation_language_selector(locale))
      end

      def translation_language_selector(locale)
        ".sidebar-section-translations__language[data-locale='#{locale}']"
      end

      def translation_row_selector(locale)
        "#{translation_language_selector(locale)} .sidebar-section-translations__row"
      end

      def translation_language_selects
        all(".sidebar-section-translations__language-select")
      end

      def primary_links_wrapper
        find(".sidebar-section-form__links-wrapper:not(.--secondary)")
      end
    end
  end
end
