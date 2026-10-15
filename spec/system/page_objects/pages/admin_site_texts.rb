# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminSiteTexts < PageObjects::Pages::Base
      def visit
        browser_page
          .goto("/admin/customize/site_texts")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def search(text)
        browser_root.locator(".site-text-search").filter(visible: true).fill(text)
        browser_page.keyboard.press("Escape")
      end

      def has_translation_key?(key)
        PlaywrightMatchers.contain_text([browser_text_pattern(key)], useInnerText: true).matches?(
          browser_root.locator(".site-text-id").filter(visible: true),
        )
      end

      def has_highlighted_translation_key?(key)
        PlaywrightMatchers.contain_text(
          [browser_exact_text_pattern(key)],
          useInnerText: true,
        ).matches?(browser_root.locator(".site-text-id .text-highlight").filter(visible: true))
      end

      def has_translation_value?(value)
        PlaywrightMatchers.contain_text([browser_text_pattern(value)], useInnerText: true).matches?(
          browser_root.locator(".site-text-value").filter(visible: true),
        )
      end

      def select_locale(locale_short_name)
        locale_selector = PageObjects::Components::SelectKit.new(".locale-search")
        locale_selector.expand
        locale_selector.select_row_by_value(locale_short_name)
        locale_selector.collapse
      end

      def select_theme(theme)
        expand_filters
        selector = PageObjects::Components::SelectKit.new(".theme-search")
        selector.expand
        selector.select_row_by_value(theme.id)
        # the combo-box closes itself on change; calling `collapse` here would
        # re-open it via a header click that can land on the clear button
        selector.has_selected_value?(theme.id)
      end

      def open_theme_filter
        expand_filters
        PageObjects::Components::SelectKit.new(".theme-search").expand
      end

      def has_theme_option?(theme, disabled: false)
        row = ".theme-search .select-kit-row[data-value='#{theme.id}']"
        unless PlaywrightMatchers.contain_text(
                 [browser_exact_text_pattern(theme.name)],
                 useInnerText: true,
               ).matches?(
                 browser_root.locator("#{row} .site-text-theme-row__name").filter(visible: true),
               )
          return false
        end
        unless PlaywrightMatchers.contain_text(
                 [browser_exact_text_pattern("##{theme.id}")],
                 useInnerText: true,
               ).matches?(
                 browser_root.locator("#{row} .site-text-theme-row__badge.--id").filter(
                   visible: true,
                 ),
               )
          return false
        end

        if disabled
          PlaywrightMatchers.contain_text(
            [browser_exact_text_pattern(I18n.t("admin_js.admin.site_text.theme_disabled"))],
            useInnerText: true,
          ).matches?(
            browser_root.locator("#{row} .site-text-theme-row__badge.--disabled").filter(
              visible: true,
            ),
          )
        else
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator("#{row} .site-text-theme-row__badge.--disabled").filter(
              visible: true,
            ),
          )
        end
      end

      def has_no_theme_filter?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".theme-search").filter(visible: true),
        )
      end

      def has_selected_theme?(theme)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern("#{theme.name} ##{theme.id}")],
          useInnerText: true,
        ).matches?(
          browser_root.locator(
            ".d-filter-controls__dropdowns .theme-search .select-kit-header",
          ).filter(visible: true),
        )
      end

      def has_all_site_texts_selected?
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(I18n.t("admin_js.admin.site_text.all_themes"))],
          useInnerText: true,
        ).matches?(browser_root.locator(".theme-search .select-kit-header").filter(visible: true))
      end

      def back_to_results
        browser_root.locator(".go-back").filter(visible: true).click
        self
      end

      def revert_translation
        browser_root.locator(".revert-site-text").filter(visible: true).click
        PageObjects::Components::Dialog.new.click_yes
        self
      end

      def reset_filters
        expand_filters
        browser_root.locator(".site-texts__reset-filters").filter(visible: true).click
        self
      end

      def toggle_only_show_overridden
        expand_filters
        browser_root.locator("#toggle-overridden").filter(visible: true).click
      end

      def toggle_only_show_outdated
        expand_filters
        browser_root.locator("#toggle-outdated").filter(visible: true).click
      end

      def toggle_only_show_results_in_selected_locale
        expand_filters
        browser_root.locator("#toggle-only-locale").filter(visible: true).click
      end

      def edit_translation(key, locale: I18n.locale, theme_id: nil)
        browser_root
          .locator(".site-text[data-site-text-id='#{key}']")
          .filter(visible: true)
          .locator(".site-text-edit")
          .filter(visible: true)
          .click
        query = { locale:, theme_id: }.compact.to_query
        PlaywrightMatchers.have_url("/admin/customize/site_texts/#{key}?#{query}").matches?(
          browser_page,
        )
      end

      def override_translation(value)
        browser_root.locator(".site-text-value").filter(visible: true).fill(value)
        browser_root.locator(".save-changes").filter(visible: true).click
      end

      def expand_filters
        if browser_root
             .locator(".d-filter-controls__toggle-filters")
             .filter(visible: true)
             .get_attribute("aria-expanded") == "false"
          browser_root.locator(".d-filter-controls__toggle-filters").filter(visible: true).click
        end
        self
      end

      def click_replace_text_button
        browser_root
          .locator(
            "[id=#{I18n.t("admin_js.admin.reseed.action.label").to_s.to_json}], [name=#{I18n.t("admin_js.admin.reseed.action.label").to_s.to_json}]",
          )
          .or(
            browser_root.get_by_role("button", name: I18n.t("admin_js.admin.reseed.action.label")),
          )
          .filter(visible: true)
          .click
      end
    end
  end
end
