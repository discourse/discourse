# frozen_string_literal: true

module PageObjects
  module Components
    class TranslationComposer < PageObjects::Components::Composer
      def has_translation_title?(value)
        expect(find("#reply-control input#translated-topic-title").value).to eq(value)
      end
    end
  end
end
