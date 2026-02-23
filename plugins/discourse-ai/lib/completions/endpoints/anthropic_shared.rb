# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      module AnthropicShared
        def normalize_model_params(model_params)
          model_params = model_params.dup
          model_params.delete(:top_p) if llm_model.lookup_custom_param("disable_top_p")
          model_params.delete(:temperature) if llm_model.lookup_custom_param("disable_temperature")
          model_params
        end

        def provider_id
          AiApiAuditLog::Provider::Anthropic
        end

        def xml_tags_to_strip(dialect)
          if dialect.prompt.has_tools?
            %w[thinking search_quality_reflection search_quality_score]
          else
            []
          end
        end

        private

        def prompt_size(prompt)
          tokenizer.size(prompt.system_prompt.to_s + " " + prompt.messages.to_s)
        end

        def xml_tools_enabled?
          !@native_tool_support
        end

        def supports_native_structured_output?
          !llm_model.lookup_custom_param("disable_native_structured_output")
        end

        def decode(response_data)
          processor.process_message(response_data)
        end

        def claude_processor
          @processor ||=
            DiscourseAi::Completions::AnthropicMessageProcessor.new(
              streaming_mode: @streaming_mode,
              partial_tool_calls: partial_tool_calls,
              output_thinking: output_thinking,
            )
        end

        def update_log_from_claude_processor(log)
          log.request_tokens = processor.input_tokens if processor.input_tokens
          log.response_tokens = processor.output_tokens if processor.output_tokens
          log.cache_read_tokens =
            processor.cache_read_input_tokens if processor.cache_read_input_tokens
          log.cache_write_tokens =
            processor.cache_creation_input_tokens if processor.cache_creation_input_tokens
        end

        def prepare_claude_payload(prompt, model_params, dialect)
          @native_tool_support = dialect.native_tool_support?

          payload =
            default_options(dialect).merge(model_params.except(:response_format)).merge(
              messages: prompt.messages,
            )

          if prompt.has_tools?
            payload[:tools] = prompt.tools
            apply_tool_choice(payload, dialect, prompt)
          end

          apply_anthropic_cache_control!(payload, prompt) if should_apply_prompt_caching?(prompt)

          payload[:system] = prompt.system_prompt if prompt.system_prompt.present? &&
            !payload[:system]

          if dialect.tool_choice == :none && prompt.has_tools?
            apply_tool_choice_none(payload, dialect)
          end

          if model_params[:response_format].present?
            response_format = model_params[:response_format].deep_symbolize_keys
            if supports_native_structured_output?
              json_schema = response_format.dig(:json_schema, :schema)
              if json_schema.present?
                payload[:output_config] ||= {}
                payload[:output_config][:format] = { type: "json_schema", schema: json_schema }
              end
            else
              payload[:messages] << { role: "assistant", content: "{" }
              @forced_json_through_prefill = true
            end
          end

          payload
        end

        def apply_tool_choice(payload, dialect, prompt)
          return if dialect.tool_choice.blank?
          if dialect.tool_choice == :none
            payload[:tool_choice] = { type: "none" }
          else
            payload[:tool_choice] = { type: "tool", name: prompt.tool_choice }
          end
        end

        def apply_tool_choice_none(payload, dialect)
          # No-op for Anthropic API (uses native tool_choice: {type: "none"})
          # Bedrock overrides this to inject a user message workaround
        end
      end
    end
  end
end
