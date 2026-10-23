# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class DiscoverEnabledValidator
      def initialize(_opts = {})
      end

      def valid_value?(value)
        value == "f" || SiteSetting.ai_discover_enabled
      end

      def error_message
        I18n.t("discourse_ai.discover.configuration.cannot_enable")
      end
    end
  end
end
