# frozen_string_literal: true

module PageObjects
  module Components
    class TranslationComposer < PageObjects::Components::Composer
      def has_translation_title?(value)
        expect(
          browser_root
            .locator("#reply-control input#translated-topic-title")
            .filter(visible: true)
            .input_value,
        ).to eq(value)
      end

      def select_locale(locale)
        selector = ".translation-selector-dropdown"
        select_kit = PageObjects::Components::SelectKit.new(selector)
        select_kit.expand
        select_kit.select_row_by_name(locale)
      end

      def fill_content(content)
        browser_root.locator(".d-editor-input").filter(visible: true).fill(content)
      end
    end
  end
end
