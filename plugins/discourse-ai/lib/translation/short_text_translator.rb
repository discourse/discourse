# frozen_string_literal: true

module DiscourseAi
  module Translation
    class ShortTextTranslator < BaseTranslator
      private

      def persona_setting
        SiteSetting.ai_translation_short_text_translator_persona
      end
    end
  end
end
