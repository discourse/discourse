# frozen_string_literal: true

module DiscourseAi
  module Translation
    class PostRawTranslator < BaseTranslator
      private

      def agent_setting
        SiteSetting.ai_translation_post_raw_translator_agent
      end
    end
  end
end
