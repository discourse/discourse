# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TopicTitleTranslator < BaseTranslator
      private

      def persona_setting
        SiteSetting.ai_translation_topic_title_translator_persona
      end
    end
  end
end
