# frozen_string_literal: true

module PageObjects
  module Components
    class TranslationComposer < PageObjects::Components::Composer
      def has_translation_title?(value)
        expect(find("#reply-control input#translated-topic-title").value).to eq(value)
      end

      def select_locale(locale)
        selector = ".translation-selector-dropdown"
        select_kit = PageObjects::Components::SelectKit.new(selector)
        select_kit.expand
        select_kit.select_row_by_name(locale)
      end

      def fill_content(content)
        find(".d-editor-input").set(content)
      end
    end
  end
end
