# frozen_string_literal: true

module DiscourseAi
  module Translation
    class ShortTextTranslator < BaseTranslator
      private

      def agent_setting
        SiteSetting.ai_translation_short_text_translator_agent
      end
    end
  end
end
