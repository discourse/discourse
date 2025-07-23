# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class LlmDependencyValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        return true if val == "f"

        if @opts[:name] == :ai_summarization_enabled || @opts[:name] == :ai_helper_enabled
          has_llms = LlmModel.count > 0
          @no_llms_configured = !has_llms
          has_llms
        else
          @llm_dependency_setting_name =
            DiscourseAi::Configuration::LlmValidator.new.choose_llm_setting_for(@opts[:name])

          SiteSetting.public_send(@llm_dependency_setting_name).present?
        end
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
