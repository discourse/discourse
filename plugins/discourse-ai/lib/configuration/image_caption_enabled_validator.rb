# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class ImageCaptionEnabledValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if val == false || val == "f" || val == "false"

        agent_validator.valid_agent_value?(SiteSetting.ai_image_caption_agent)
      end

      def error_message
        agent_validator.error_message
      end

      private

      def agent_validator
        @agent_validator ||= ImageCaptionAgentValidator.new(@opts)
      end
    end
  end
end
