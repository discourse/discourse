# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminSiteTexts < PageObjects::Pages::Base
      def visit
        page.visit("/admin/customize/site_texts")
        self
      end

      def search(text)
        find(".site-text-search").fill_in(with: text)
        page.send_keys(:escape)
      end

      def has_translation_key?(key)
        has_css?(".site-text-id", text: key)
      end

      def has_translation_value?(value)
        has_css?(".site-text-value", text: value)
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
        selector.collapse
      end

      def has_no_theme_filter?
        has_no_css?(".theme-search")
      end

      def has_selected_theme?(theme)
        has_css?(".d-filter-controls__dropdowns .theme-search .select-kit-header", text: theme.name)
      end

      def has_all_site_texts_selected?
        has_css?(
          ".theme-search .select-kit-header",
          text: I18n.t("admin_js.admin.site_text.all_themes"),
        )
      end

      def back_to_results
        find(".go-back").click
        self
      end

      def revert_translation
        find(".revert-site-text").click
        PageObjects::Components::Dialog.new.click_yes
        self
      end

      def reset_filters
        expand_filters
        find(".site-texts__reset-filters").click
        self
      end

      def toggle_only_show_overridden
        expand_filters
        find("#toggle-overridden").click
      end

      def toggle_only_show_outdated
        expand_filters
        find("#toggle-outdated").click
      end

      def toggle_only_show_results_in_selected_locale
        expand_filters
        find("#toggle-only-locale").click
      end

      def edit_translation(key, locale: I18n.locale, theme_id: nil)
        find(".site-text[data-site-text-id='#{key}']").find(".site-text-edit").click
        query = { locale:, theme_id: }.compact.to_query
        has_current_path?("/admin/customize/site_texts/#{key}?#{query}", ignore_query: false)
      end

      def override_translation(value)
        find(".site-text-value").fill_in(with: value)
        find(".save-changes").click
      end

      def expand_filters
        if find(".d-filter-controls__toggle-filters")["aria-expanded"] == "false"
          find(".d-filter-controls__toggle-filters").click
        end
        self
      end

      def click_replace_text_button
        click_button(I18n.t("admin_js.admin.reseed.action.label"))
      end
    end
  end
end
