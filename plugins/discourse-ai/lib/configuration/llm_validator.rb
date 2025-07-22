# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class InvalidSeededModelError < StandardError
    end

    class LlmValidator
      def initialize(opts = {})
        @opts = opts
      end

      def valid_value?(val)
        if val == ""
          @parent_module_name = modules_and_choose_llm_settings.invert[@opts[:name]]

          @parent_enabled = SiteSetting.public_send(@parent_module_name)
          return !@parent_enabled
        end

        allowed_seeded_model?(val)

        run_test(val).tap { |result| @unreachable = result }
      rescue DiscourseAi::Configuration::InvalidSeededModelError => e
        @unreachable = true
        false
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

      def modules_using(llm_model)
        choose_llm_settings = modules_and_choose_llm_settings.values

        choose_llm_settings.select { |s| SiteSetting.public_send(s) == "custom:#{llm_model.id}" }
      end

      def error_message
        if @parent_enabled
          return(
            I18n.t(
              "discourse_ai.llm.configuration.disable_module_first",
              setting: @parent_module_name,
            )
          )
        end

        if @invalid_seeded_model
          return I18n.t("discourse_ai.llm.configuration.invalid_seeded_model")
        end

        return unless @unreachable

        I18n.t("discourse_ai.llm.configuration.model_unreachable")
      end

      def choose_llm_setting_for(module_enabler_setting)
        modules_and_choose_llm_settings[module_enabler_setting]
      end

      def modules_and_choose_llm_settings
        {
          ai_embeddings_semantic_search_enabled: :ai_embeddings_semantic_search_hyde_model,
          ai_helper_enabled: :ai_helper_model,
          ai_summarization_enabled: :ai_summarization_model,
          ai_translation_enabled: :ai_translation_model,
        }
      end

      def allowed_seeded_model?(val)
        id = val.split(":").last
        return true if id.to_i > 0

        setting = @opts[:name]
        allowed_list = SiteSetting.public_send("#{setting}_allowed_seeded_models")

        if allowed_list.split("|").exclude?(id)
          @invalid_seeded_model = true
          raise DiscourseAi::Configuration::InvalidSeededModelError.new
        end
      end
    end
  end
end
