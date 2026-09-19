# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class ImageCaptionAgentValidator
      DEFAULT_AGENT_ID = "-26"

      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if val.to_s == DEFAULT_AGENT_ID

        valid_agent_value?(val)
      end

      def valid_agent_value?(val)
        agent = AiAgent.find_by(id: val.to_i)
        return invalid(:agent_missing) if agent.blank?

        agent_class = agent.class_instance
        return invalid(:agent_vision_disabled) if !agent_class&.vision_enabled

        llm_model =
          DiscourseAi::AiHelper::Assistant.find_ai_helper_model(
            DiscourseAi::AiHelper::Assistant::IMAGE_CAPTION,
            agent_class,
          )
        return invalid(:llm_missing) if llm_model.blank?
        return invalid(:llm_vision_disabled) if !llm_model.vision_enabled?

        true
      end

      def error_message
        I18n.t("discourse_ai.image_caption.configuration.#{@error_key}")
      end

      private

      def invalid(error_key)
        @error_key = error_key
        false
      end
    end
  end
end
