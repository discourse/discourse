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
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(RAW_TOGGLE_SELECTOR).filter(visible: true),
        )
      end

      def has_no_raw_toggle?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(RAW_TOGGLE_SELECTOR).filter(visible: true),
        )
      end

      def raw_toggle
        PageObjects::Components::DToggleSwitch.new(
          "#{RAW_TOGGLE_SELECTOR} .d-toggle-switch__checkbox",
        )
      end

      def click_original_tab
        browser_root.locator(ORIGINAL_TAB_SELECTOR).filter(visible: true).click
        self
      end

      def click_translation_tab
        browser_root.locator(TRANSLATION_TAB_SELECTOR).filter(visible: true).click
        self
      end

      def original_tab_active?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{ORIGINAL_TAB_SELECTOR}.active").filter(visible: true),
        )
      end

      def translation_tab_active?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{TRANSLATION_TAB_SELECTOR}.active").filter(visible: true),
        )
      end

      def has_raw_markdown_content?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(RAW_CONTENT_SELECTOR).filter(visible: true),
        )
      end

      def has_no_raw_markdown_content?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(RAW_CONTENT_SELECTOR).filter(visible: true),
        )
      end

      def raw_markdown_content
        browser_root.locator(RAW_CONTENT_SELECTOR).filter(visible: true).inner_text.strip
      end

      def has_rendered_content?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(RENDERED_CONTENT_SELECTOR).filter(visible: true),
        ) &&
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(RAW_CONTENT_SELECTOR).filter(visible: true),
          )
      end

      def has_rendered_preview_image?(alt:)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_page.locator(
            "xpath=" +
              ".//*[contains(concat(' ', normalize-space(@class), ' '), ' d-editor-translation-preview-content ')]" \
                "//*[contains(concat(' ', normalize-space(@class), ' '), ' d-editor-preview ')]" \
                "//img[@alt=#{xpath_literal(alt)}][@src != '/images/transparent.png'][not(@data-orig-src)]",
          ).filter(visible: true),
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
