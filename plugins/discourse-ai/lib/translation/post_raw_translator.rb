# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostRawTranslator < BaseTranslator
      private

      def persona_setting
        SiteSetting.ai_translation_post_raw_translator_persona
      end
    end
  end
end
