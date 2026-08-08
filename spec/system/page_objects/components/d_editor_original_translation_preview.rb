# frozen_string_literal: true

module PageObjects
  module Components
    class DEditorOriginalTranslationPreview < PageObjects::Components::Base
      PREVIEW_SELECTOR = ".d-editor-translation-preview-wrapper"
      RAW_TOGGLE_SELECTOR = ".d-editor-translation-preview-header__raw-toggle"
      RAW_CONTENT_SELECTOR = "pre.d-editor-translation-preview-raw"
      RENDERED_CONTENT_SELECTOR = ".d-editor-translation-preview-content"
      RENDERED_PREVIEW_IMAGE_SELECTOR = "#{RENDERED_CONTENT_SELECTOR} .d-editor-preview img"
      ORIGINAL_TAB_SELECTOR = ".d-editor-translation-preview-header__controls button:nth-child(1)"
      TRANSLATION_TAB_SELECTOR =
        ".d-editor-translation-preview-header__controls button:nth-child(2)"

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
        find(ORIGINAL_TAB_SELECTOR).click
        self
      end

      def click_translation_tab
        find(TRANSLATION_TAB_SELECTOR).click
        self
      end

      def original_tab_active?
        page.has_css?("#{ORIGINAL_TAB_SELECTOR}.active")
      end

      def translation_tab_active?
        page.has_css?("#{TRANSLATION_TAB_SELECTOR}.active")
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

      def has_rendered_preview_image?(alt:)
        page.has_xpath?(
          ".//*[contains(concat(' ', normalize-space(@class), ' '), ' d-editor-translation-preview-content ')]" \
            "//*[contains(concat(' ', normalize-space(@class), ' '), ' d-editor-preview ')]" \
            "//img[@alt=#{xpath_literal(alt)}][@src != '/images/transparent.png'][not(@data-orig-src)]",
        )
      end

      private

      def xpath_literal(value)
        value = value.to_s

        return "'#{value}'" if !value.include?("'")
        return "\"#{value}\"" if !value.include?('"')

        "concat(#{value.split("'").map { |part| "'#{part}'" }.join(%{, "\"'\"", })})"
      end
    end
  end
end
