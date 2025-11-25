# frozen_string_literal: true

module PageObjects
  module Components
    class DEditorOriginalTranslationPreview < PageObjects::Components::Base
      PREVIEW_SELECTOR = ".d-editor-translation-preview-wrapper"
      RAW_TOGGLE_SELECTOR = ".d-editor-translation-preview-header__raw-toggle"
      RAW_CONTENT_SELECTOR = "pre.d-editor-translation-preview-raw"
      RENDERED_CONTENT_SELECTOR = ".d-editor-translation-preview-content"

      def has_raw_toggle?
        page.has_css?(RAW_TOGGLE_SELECTOR)
      end

      def has_no_raw_toggle?
        page.has_no_css?(RAW_TOGGLE_SELECTOR)
      end

      def raw_toggle
        PageObjects::Components::DToggleSwitch.new(
          "#{RAW_TOGGLE_SELECTOR} .d-toggle-switch__checkbox",
        )
      end

      def click_original_tab
        find("button", text: I18n.t("js.composer.translations.original")).click
        self
      end

      def click_translation_tab
        find("button", text: I18n.t("js.composer.translations.translation")).click
        self
      end

      def original_tab_active?
        page.has_css?("button.active", text: I18n.t("js.composer.translations.original"))
      end

      def translation_tab_active?
        page.has_css?("button.active", text: I18n.t("js.composer.translations.translation"))
      end

      def has_raw_markdown_content?
        page.has_css?(RAW_CONTENT_SELECTOR)
      end

      def has_no_raw_markdown_content?
        page.has_no_css?(RAW_CONTENT_SELECTOR)
      end

      def raw_markdown_content
        find(RAW_CONTENT_SELECTOR).text
      end

      def has_rendered_content?
        page.has_css?(RENDERED_CONTENT_SELECTOR) && page.has_no_css?(RAW_CONTENT_SELECTOR)
      end
    end
  end
end
