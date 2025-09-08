# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class SpamDetectionValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        # only validate when enabling spam detection
        return true if val == "f" || val == "false"
        return true if AiModerationSetting.spam

        false
      end

      def error_message
        I18n.t("discourse_ai.spam_detection.configuration_missing")
      end
    end
  end
end
