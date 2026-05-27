# frozen_string_literal: true

module DiscourseAi
  module Translation
    class TopicTitleTranslator < BaseTranslator
      private

      def agent_setting
        SiteSetting.ai_translation_topic_title_translator_agent
      end
    end
  end
end
