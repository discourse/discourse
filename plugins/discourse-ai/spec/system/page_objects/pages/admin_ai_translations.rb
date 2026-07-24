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

      def has_overview_cards?
        page.has_css?(".ai-translation-model-progress-overview-card", count: 4)
      end

      def has_no_overview_cards?
        page.has_no_css?(".ai-translation-model-progress-overview-card")
      end

      def toggle_target(target_type)
        page.find(
          ".ai-translation-model-progress-overview-card[data-target-type='#{target_type}']",
        ).click
        self
      end

      def has_expanded_target?(target_type)
        page.has_css?(
          ".ai-translation-model-progress-overview-card[data-target-type='#{target_type}'][aria-expanded='true']",
        )
      end

      def has_no_expanded_target?
        page.has_no_css?(".ai-translation-model-progress-overview-card[aria-expanded='true']")
      end

      def has_detail_table?
        page.has_css?(".ai-translation-model-progress-detail .d-table")
      end

      def has_no_detail_table?
        page.has_no_css?(".ai-translation-model-progress-detail .d-table")
      end

      def has_detail_row?(locale:, translated:, pending:, denominator:)
        page.has_css?(
          ".ai-translation-locale-progress__row",
          text: /#{locale}.*#{translated}.*#{pending}.*#{denominator}/m,
        )
      end

      def has_locale_selector?
        page.has_css?(".ai-translations__settings-panel .multi-select")
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
