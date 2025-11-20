# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Anthropic < Base
        include AnthropicPromptCache
        def self.can_contact?(model_provider)
          model_provider == "anthropic"
        end

        def normalize_model_params(model_params)
          # max_tokens, temperature, stop_sequences are already supported
          model_params = model_params.dup
          model_params.delete(:top_p) if llm_model.lookup_custom_param("disable_top_p")
          model_params.delete(:temperature) if llm_model.lookup_custom_param("disable_temperature")
          model_params
        end

        def default_options(dialect)
          mapped_model =
            case llm_model.name
            when "claude-2"
              "claude-2.1"
            when "claude-instant-1"
              "claude-instant-1.2"
            when "claude-3-haiku"
              "claude-3-haiku-20240307"
            when "claude-3-sonnet"
              "claude-3-sonnet-20240229"
            when "claude-3-opus"
              "claude-3-opus-20240229"
            when "claude-3-5-sonnet"
              "claude-3-5-sonnet-latest"
            when "claude-3-7-sonnet"
              "claude-3-7-sonnet-latest"
            when "claude-4-opus"
              "claude-4-opus-20250514"
            when "claude-4-sonnet"
              "claude-4-sonnet-20250514"
            else
              llm_model.name
            end

          # Note: Anthropic requires this param
          max_tokens = 4096
          # 3.5 and 3.7 models have a higher token limit
          max_tokens = 8192 if mapped_model.match?(/3.[57]/)

          options = { model: mapped_model, max_tokens: max_tokens }

          # reasoning has even higher token limits
          if llm_model.lookup_custom_param("enable_reasoning")
            reasoning_tokens =
              llm_model.lookup_custom_param("reasoning_tokens").to_i.clamp(1024, 32_768)

            # this allows for lots of tokens beyond reasoning
            options[:max_tokens] = reasoning_tokens + 30_000
            options[:thinking] = { type: "enabled", budget_tokens: reasoning_tokens }
          end

          options[:stop_sequences] = ["</function_calls>"] if !dialect.native_tool_support? &&
            dialect.prompt.has_tools?

          options
        end

        def provider_id
          AiApiAuditLog::Provider::Anthropic
        end

        private

        def xml_tags_to_strip(dialect)
          if dialect.prompt.has_tools?
            %w[thinking search_quality_reflection search_quality_score]
          else
            []
          end
        end

        # this is an approximation, we will update it later if request goes through
        def prompt_size(prompt)
          tokenizer.size(prompt.system_prompt.to_s + " " + prompt.messages.to_s)
        end

        def model_uri
          URI(llm_model.url)
        end

        def xml_tools_enabled?
          !@native_tool_support
        end

        def prepare_payload(prompt, model_params, dialect)
          @native_tool_support = dialect.native_tool_support?

          payload =
            default_options(dialect).merge(model_params.except(:response_format)).merge(
              messages: prompt.messages,
            )

          # Handle tools first
          if prompt.has_tools?
            payload[:tools] = prompt.tools
            if dialect.tool_choice.present?
              if dialect.tool_choice == :none
                payload[:tool_choice] = { type: "none" }
              else
                payload[:tool_choice] = { type: "tool", name: prompt.tool_choice }
              end
            end
          end

          # Apply prompt caching if enabled
          apply_anthropic_cache_control!(payload, prompt) if should_apply_prompt_caching?(prompt)

          # Set system prompt if not already set by caching
          payload[:system] = prompt.system_prompt if prompt.system_prompt.present? &&
            !payload[:system]
          payload[:stream] = true if @streaming_mode

          prefilled_message = +""

          # Handle tool choice prefilling
          if dialect.tool_choice == :none && prompt.has_tools?
            # prefill prompt to nudge LLM to generate a response that is useful.
            # without this LLM (even 3.7) can get confused and start text preambles for a tool calls.
            prefilled_message << dialect.no_more_tool_calls_text
          end

          # Prefill prompt to force JSON output.
          if model_params[:response_format].present?
            prefilled_message << " " if !prefilled_message.empty?
            prefilled_message << "{"
            @forced_json_through_prefill = true
          end

          if !prefilled_message.empty?
            payload[:messages] << { role: "assistant", content: prefilled_message }
          end

          payload
        end

        def prepare_request(payload)
          headers = {
            "anthropic-version" => "2023-06-01",
            "x-api-key" => llm_model.api_key,
            "content-type" => "application/json",
          }

          # Add caching headers if configured
          headers.merge!(anthropic_cache_headers)

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def decode_chunk(partial_data)
          @decoder ||= JsonStreamDecoder.new
          (@decoder << partial_data)
            .map { |parsed_json| processor.process_streamed_message(parsed_json) }
            .compact
        end

        def decode(response_data)
          processor.process_message(response_data)
        end

        def processor
          @processor ||=
            DiscourseAi::Completions::AnthropicMessageProcessor.new(
              streaming_mode: @streaming_mode,
              partial_tool_calls: partial_tool_calls,
              output_thinking: output_thinking,
            )
        end

        def has_tool?(_response_data)
          processor.tool_calls.present?
        end

        def tool_calls
          processor.to_tool_calls
        end

        def final_log_update(log)
          log.request_tokens = processor.input_tokens if processor.input_tokens
          log.response_tokens = processor.output_tokens if processor.output_tokens
          log.cache_read_tokens =
            processor.cache_read_input_tokens if processor.cache_read_input_tokens
          log.cache_write_tokens =
            processor.cache_creation_input_tokens if processor.cache_creation_input_tokens
        end
      end
    end
  end
end
