# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class LlmDependencyValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if val == "f"

        @llm_dependency_setting_name = :ai_default_llm_model

        SiteSetting.public_send(@llm_dependency_setting_name).present?
      end

      def error_message
        if @llm_dependency_setting_name
          I18n.t(
            "discourse_ai.llm.configuration.set_llm_first",
            setting: @llm_dependency_setting_name,
          )
        elsif @no_llms_configured
          I18n.t("discourse_ai.llm.configuration.create_llm")
        end
      end
    end
  end
end
