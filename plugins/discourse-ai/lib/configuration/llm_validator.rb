# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class LlmValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        if val == ""
          if @opts[:name] == :ai_default_llm_model
            @parent_module_names = []

            enabled_settings.each do |setting_name|
              if SiteSetting.public_send(setting_name) == true
                @parent_module_names << setting_name
                @parent_enabled = true
              end
            end

            return !@parent_enabled
          end
        end

        run_test(val).tap { |result| @unreachable = result }
      rescue StandardError => e
        raise e if Rails.env.test?
        @unreachable = true
        true
      end

      def run_test(val)
        DiscourseAi::Completions::Llm
          .proxy(val)
          .generate("How much is 1 + 1?", user: nil, feature_name: "llm_validator")
          .present?
      end

      def is_using(llm_model)
        in_use_by = AiPersona.where(default_llm_id: llm_model.id).pluck(:name)

        in_use_by << "ai_default_llm_model" if SiteSetting.ai_default_llm_model.to_i == llm_model.id

        in_use_by
      end

      def error_message
        if @parent_enabled && @parent_module_names.present?
          return(
            I18n.t(
              "discourse_ai.llm.configuration.disable_modules_first",
              settings: @parent_module_names.join(", "),
            )
          )
        end

        return unless @unreachable

        I18n.t("discourse_ai.llm.configuration.model_unreachable")
      end

      def enabled_settings
        %i[
          ai_embeddings_semantic_search_enabled
          ai_helper_enabled
          ai_summarization_enabled
          ai_translation_enabled
        ]
      end
    end
  end
end
