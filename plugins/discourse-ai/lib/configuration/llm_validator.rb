# frozen_string_literal: true

module DiscourseAi
  module Configuration
    class LlmValidator
      TEST_PROMPT = "How much is 1 + 1?"
      # Must finish well inside the web worker timeout, or the worker is killed
      # before the provider's error reaches the admin.
      TEST_TIMEOUT_SECONDS = 20

      attr_reader :last_failed_mode

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
        llm = DiscourseAi::Completions::Llm.proxy(val)
        cancel_manager = DiscourseAi::Completions::CancelManager.new(timeout: TEST_TIMEOUT_SECONDS)
        cancel_manager.start_monitor { cancel_manager.expired? }

        @last_failed_mode = :non_streaming
        response = within_deadline(cancel_manager) { probe(llm, cancel_manager) }
        raise empty_response_error if response.blank?

        @last_failed_mode = :streaming
        streamed = +""
        within_deadline(cancel_manager) do
          probe(llm, cancel_manager) { |partial| streamed << partial.to_s if partial.is_a?(String) }
        end
        raise empty_response_error if streamed.blank?

        @last_failed_mode = nil
        true
      ensure
        cancel_manager&.stop_monitor
      end

      def is_using(llm_model)
        in_use_by = AiAgent.where(default_llm_id: llm_model.id).pluck(:name)
        in_use_by.concat(
          LlmModel
            .where(vision_llm_model_id: llm_model.id)
            .order(:display_name)
            .pluck(:display_name),
        )

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

      private

      def probe(llm, cancel_manager, &blk)
        llm.generate(
          TEST_PROMPT,
          user: @opts[:user] || Discourse.system_user,
          feature_name: "llm_validator",
          top_p: 0.9,
          cancel_manager: cancel_manager,
          &blk
        )
      end

      # A transport timeout can fire just before the monitor cancels, surfacing as a
      # network error instead, so judge by the deadline rather than the error type.
      def within_deadline(cancel_manager)
        result = yield
        raise timeout_error if cancel_manager.cancelled?
        result
      rescue StandardError => e
        raise timeout_error if cancel_manager.expired?
        raise
      end

      def timeout_error
        DiscourseAi::Completions::Endpoints::Base::CompletionFailed.new(
          I18n.t("discourse_ai.llm.configuration.test_timeout", count: TEST_TIMEOUT_SECONDS),
        )
      end

      def empty_response_error
        DiscourseAi::Completions::Endpoints::Base::CompletionFailed.new(
          I18n.t("discourse_ai.llm.configuration.empty_response"),
        )
      end
    end
  end
end
