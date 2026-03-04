# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      module AnthropicShared
        def normalize_model_params(model_params)
          model_params = model_params.dup

          thinking_enabled =
            llm_model.lookup_custom_param("adaptive_thinking") ||
              llm_model.lookup_custom_param("enable_reasoning")

          if thinking_enabled
            model_params.delete(:temperature)
            model_params.delete(:top_p)
          else
            model_params.delete(:top_p) if llm_model.lookup_custom_param("disable_top_p")
            if llm_model.lookup_custom_param("disable_temperature")
              model_params.delete(:temperature)
            end
          end

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
          elsif thinking_enabled?(payload)
            inject_force_tool_guidance(payload, prompt.tool_choice)
          else
            payload[:tool_choice] = { type: "tool", name: prompt.tool_choice }
          end
        end

        def thinking_enabled?(payload)
          thinking = payload[:thinking]
          thinking.present? && %w[enabled adaptive].include?(thinking[:type].to_s)
        end

        def inject_force_tool_guidance(payload, tool_name)
          guidance =
            "Important: You must respond by calling the '#{tool_name}' tool immediately. " \
              "Do not respond with text."
          last_msg = payload[:messages]&.last
          if last_msg && last_msg[:role] == "user"
            if last_msg[:content].is_a?(String)
              last_msg[:content] = last_msg[:content] + "\n\n#{guidance}"
            elsif last_msg[:content].is_a?(Array)
              last_msg[:content] << { type: "text", text: guidance }
            end
          else
            payload[:messages] << { role: "user", content: guidance }
          end
        end
      end
    end
  end
end
