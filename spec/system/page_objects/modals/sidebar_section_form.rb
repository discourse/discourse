# frozen_string_literal: true

module PageObjects
  module Modals
    class SidebarSectionForm < PageObjects::Modals::Base
      def fill_name(name)
        browser_root
          .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
          .and(
            browser_root.locator(
              "[id=#{"section-name".to_s.to_json}], [name=#{"section-name".to_s.to_json}]",
            ).or(browser_root.get_by_label("section-name", exact: true)),
          )
          .filter(visible: true)
          .fill(name)
      end

      def fill_link(name, url, icon = "link")
        browser_root
          .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
          .and(
            browser_root.locator(
              "[id=#{"link-name".to_s.to_json}], [name=#{"link-name".to_s.to_json}]",
            ).or(browser_root.get_by_label("link-name", exact: true)),
          )
          .filter(visible: true)
          .first
          .fill(name)
        browser_root
          .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
          .and(
            browser_root.locator(
              "[id=#{"link-url".to_s.to_json}], [name=#{"link-url".to_s.to_json}]",
            ).or(browser_root.get_by_label("link-url", exact: true)),
          )
          .filter(visible: true)
          .first
          .fill(url)
        icon_picker = first_link_icon_picker
        icon_picker.expand
        icon_picker.select_icon(icon)
      end

      def fill_last_link(name, url, icon = "link")
        primary_links_wrapper
          .locator(".sidebar-section-form-link")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .last
          .then do |link_row|
            link_row
              .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
              .and(
                link_row.locator(
                  "[id=#{"link-name".to_s.to_json}], [name=#{"link-name".to_s.to_json}]",
                ).or(link_row.get_by_label("link-name", exact: true)),
              )
              .filter(visible: true)
              .fill(name)
            link_row
              .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
              .and(
                link_row.locator(
                  "[id=#{"link-url".to_s.to_json}], [name=#{"link-url".to_s.to_json}]",
                ).or(link_row.get_by_label("link-url", exact: true)),
              )
              .filter(visible: true)
              .fill(url)

            icon_picker = PageObjects::Components::DIconGridPicker.new(link_row)
            icon_picker.expand
            icon_picker.select_icon(icon)
          end
      end

      def first_link_icon_picker
        PageObjects::Components::DIconGridPicker.new(
          browser_root.locator(".sidebar-section-form-link").filter(visible: true).first,
        )
      end

      def add_link
        browser_root
          .locator(".sidebar-section-form-modal .add-link")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .first
          .click
        self
      end

      def mark_as_public
        browser_root.locator(".d-modal .mark-public").filter(visible: true).click
      end

      def remove_last_link
        browser_root
          .locator(".delete-link")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .last
          .click
      end

      def open_translations
        browser_root
          .locator(".sidebar-section-form__manage-translations")
          .filter(visible: true)
          .click
        self
      end

      def close_translations
        browser_root.locator(".sidebar-section-translations__back").filter(visible: true).click
        self
      end

      def add_language(locale)
        browser_root
          .locator(".sidebar-section-translations__add-language")
          .filter(visible: true)
          .click
        PageObjects::Components::DNativeSelect.new(translation_language_selects.last).select(locale)
      end

      def remove_language(locale)
        translation_language(locale)
          .locator(".sidebar-section-translations__remove-language")
          .filter(visible: true)
          .click
      end

      def fill_translation(locale, source, value)
        translation_language(locale)
          .locator(".sidebar-section-translations__row")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(source))
          .locator("input")
          .filter(visible: true)
          .fill(value)
      end

      def delete
        browser_root.locator("#delete-section").filter(visible: true).click
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
        browser_root.locator(".reset-link").filter(visible: true).click
        PageObjects::Components::Dialog.new.click_yes
        closed?
        self
      end

      def save
        browser_root.locator("#save-section").filter(visible: true).click
        self
      end

      def visible?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".sidebar-section-form-modal").filter(visible: true),
        )
      end

      def closed?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".sidebar-section-form-modal").filter(visible: true),
        )
      end

      def has_disabled_save?
        browser_root
          .get_by_role("button")
          .and(
            browser_root.locator("[id=#{"Save".to_s.to_json}], [name=#{"Save".to_s.to_json}]").or(
              browser_root.get_by_role("button", name: "Save"),
            ),
          )
          .and(browser_root.locator(":disabled"))
          .filter(visible: true)
      end

      def has_enabled_save?
        browser_root
          .get_by_role("button")
          .and(
            browser_root.locator("[id=#{"Save".to_s.to_json}], [name=#{"Save".to_s.to_json}]").or(
              browser_root.get_by_role("button", name: "Save"),
            ),
          )
          .and(browser_root.locator(":not(:disabled)"))
          .filter(visible: true)
      end

      def has_localization_controls?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".sidebar-section-form__manage-translations").filter(visible: true),
        )
      end

      def has_no_localization_controls?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".sidebar-section-form__manage-translations").filter(visible: true),
        )
      end

      def has_locale_option?(locale)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".sidebar-section-translations__language-select option[value='#{locale}']",
          ),
        )
      end

      def has_no_locale_option?(locale)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            ".sidebar-section-translations__language-select option[value='#{locale}']",
          ),
        )
      end

      def has_translation_languages?(count)
        PlaywrightMatchers.have_count(count).matches?(
          browser_root.locator(".sidebar-section-translations__language").filter(visible: true),
        )
      end

      def has_translation_row?(locale, source)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(source)],
          useInnerText: true,
        ).matches?(browser_root.locator(translation_row_selector(locale)).filter(visible: true))
      end

      def has_no_translation_row?(locale, source)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(source)],
          useInnerText: true,
        ).does_not_match?(
          browser_root.locator(translation_row_selector(locale)).filter(visible: true),
        )
      end

      def has_translation_language?(locale)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(translation_language_selector(locale)).filter(visible: true),
        )
      end

      def has_selected_translation_language?(locale)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{translation_language_selector(locale)} " \
              ".sidebar-section-translations__language-select option[value='#{locale}']:checked",
          ),
        )
      end

      def has_no_translation_language?(locale)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(translation_language_selector(locale)).filter(visible: true),
        )
      end

      def has_disabled_translation_locale?(locale, disabled)
        PlaywrightMatchers.have_count(0).does_not_match?(
          translation_language(locale).locator(
            ".sidebar-section-translations__language-select option[value='#{disabled}'][disabled]",
          ),
        )
      end

      def has_no_add_language?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".sidebar-section-translations__add-language").filter(visible: true),
        )
      end

      def has_section_links_label?
        PlaywrightMatchers.contain_text(
          [browser_text_pattern("Section links")],
          useInnerText: true,
        ).matches?(browser_root.locator(".sidebar-section-form__links-label").filter(visible: true))
      end

      def has_section_name?(name)
        PlaywrightMatchers.have_value(name).matches?(
          browser_root
            .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
            .and(
              browser_root.locator(
                "[id=#{"section-name".to_s.to_json}], [name=#{"section-name".to_s.to_json}]",
              ).or(browser_root.get_by_label("section-name", exact: true)),
            )
            .filter(visible: true),
        )
      end

      def has_first_link_name?(name)
        PlaywrightMatchers.have_value(name).matches?(
          browser_root
            .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
            .and(
              browser_root.locator(
                "[id=#{"link-name".to_s.to_json}], [name=#{"link-name".to_s.to_json}]",
              ).or(browser_root.get_by_label("link-name", exact: true)),
            )
            .filter(visible: true)
            .first,
        )
      end

      def topics_link
        browser_root.locator(".draggable[data-link-name='Topics']").filter(visible: true)
      end

      def review_link
        browser_root.locator(".draggable[data-link-name='Review']").filter(visible: true)
      end

      # Methods for when the enable_new_reordering_controls upcoming change is
      # enabled. topics_link/review_link above keep main's drag-source lookups.
      #
      # TODO (ui-kit-reorderable-list-cleanup) fold these over them once the change
      # ships.

      # Driven by the keyboard rather than clicked: the reorder control exists
      # because a drag has no keyboard path, so the spec has to go through the
      # keyboard to be testing the thing it was added for.
      def move_link_up(name)
        link_handle(name).press(%w[Alt ArrowUp].join("+"))
      end

      def move_link_down(name)
        link_handle(name).press(%w[Alt ArrowDown].join("+"))
      end

      # Presses whatever the previous move left focused, rather than looking the
      # handle up again. Finding it by name would pass even if focus had been lost,
      # which is most of what there is to get wrong here.
      def press_focused_link_move_down
        browser_page.then { |pw_page| pw_page.keyboard.press("Alt+ArrowDown") }
      end

      def open_focused_link_menu
        browser_page.then { |pw_page| pw_page.keyboard.press("Enter") }
      end

      # The link whose row currently holds focus. The row is the cursor's item, so
      # this is what says focus survived a move; the handle inside it is a pointer
      # affordance and never takes focus from the keyboard.
      def focused_link_name
        browser_page.evaluate(
          "function(arguments) { return document.activeElement?.dataset?.linkName }",
          arg: [],
        )
      end

      def link_handle(name)
        browser_root.locator("button[aria-label='Reorder #{name}']").filter(visible: true)
      end

      # Read from the name inputs, not from the drag handles, so it reports the
      # order on a touch screen too, where no handle renders. Scoped away from the
      # secondary list, which renders in a wrapper of its own.
      def link_names
        browser_root
          .locator(".sidebar-section-form__links-wrapper:not(.--secondary) input[name='link-name']")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map(&:input_value)
      end

      def has_source_language?(locale)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".sidebar-section-form__source-locale-select option[value='#{locale}']:checked",
          ),
        )
      end

      def has_no_source_language_control?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".sidebar-section-form__source-locale").filter(visible: true),
        )
      end

      def select_source_language(locale)
        PageObjects::Components::DNativeSelect.new(
          ".sidebar-section-form__source-locale-select",
        ).select(locale)
      end

      private

      def translation_language(locale)
        browser_root.locator(translation_language_selector(locale)).filter(visible: true)
      end

      def translation_language_selector(locale)
        ".sidebar-section-translations__language[data-locale='#{locale}']"
      end

      def translation_row_selector(locale)
        "#{translation_language_selector(locale)} .sidebar-section-translations__row"
      end

      def translation_language_selects
        browser_root
          .locator(".sidebar-section-translations__language-select")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
      end

      def primary_links_wrapper
        browser_root.locator(".sidebar-section-form__links-wrapper").filter(visible: true)
      end
    end
  end
end
