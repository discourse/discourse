# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminAiTranslations < PageObjects::Pages::Base
      def visit
        page.visit "/admin/plugins/discourse-ai/ai-translations"
      end

      def has_translations_page?
        page.has_css?(".ai-translations")
      end

      def has_toggle?
        page.has_css?(".ai-translations__toggle-container .d-toggle-switch")
      end

      def has_toggle_disabled?
        page.has_css?(".d-toggle-switch__checkbox[disabled]")
      end

      def has_chart?
        page.has_css?(".ai-translations__chart")
      end

      def has_no_chart?
        page.has_no_css?(".ai-translations__chart")
      end

      def has_charts_section?
        page.has_css?(".ai-translations__charts")
      end

      def has_locale_selector?
        page.has_css?(".alert.alert-info .multi-select")
      end

      def has_translation_settings_button?
        page.has_css?(".ai-translation-settings-button")
      end

      def has_localization_settings_button?
        page.has_css?(".ai-localization-settings-button")
      end
    end
  end
end
