# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      module AnthropicShared
        EFFORT_VALUES = %w[low medium high xhigh max].freeze
        THINKING_BUDGETS = {
          "minimal" => 1024,
          "low" => 4096,
          "medium" => 8192,
          "high" => 16_384,
          "xhigh" => 32_768,
          "max" => 32_768,
        }.freeze
        MIN_THINKING_BUDGET = 1024
        MIN_VISIBLE_OUTPUT_TOKENS = 1024
        # Models we cannot identify get a generous assumed cap so an
        # undersized guess surfaces as an error when an admin tests the
        # model, instead of silently truncating every response.
        UNKNOWN_MODEL_MAX_OUTPUT_TOKENS = 64_000
        # Friendly or legacy names mapped to the canonical Anthropic API
        # model name. Dated canonical names pass through unchanged.
        CLAUDE_MODEL_ALIASES = {
          "claude-2" => "claude-2.1",
          "claude-instant-1" => "claude-instant-1.2",
          "claude-instant" => "claude-instant-1.2",
          "claude-3-haiku" => "claude-3-haiku-20240307",
          "claude-3-sonnet" => "claude-3-sonnet-20240229",
          "claude-3-opus" => "claude-3-opus-20240229",
          "claude-3-5-sonnet" => "claude-3-5-sonnet-20241022",
          "claude-3-5-sonnet-latest" => "claude-3-5-sonnet-20241022",
          "claude-3-5-haiku" => "claude-3-5-haiku-20241022",
          "claude-3-5-haiku-latest" => "claude-3-5-haiku-20241022",
          "claude-3-7-sonnet" => "claude-3-7-sonnet-20250219",
          "claude-3-7-sonnet-latest" => "claude-3-7-sonnet-20250219",
          "claude-4-opus" => "claude-opus-4-20250514",
          "claude-4-sonnet" => "claude-sonnet-4-20250514",
          "claude-opus-4" => "claude-opus-4-20250514",
          "claude-sonnet-4" => "claude-sonnet-4-20250514",
          "claude-opus-4-1" => "claude-opus-4-1-20250805",
          "claude-opus-4-5" => "claude-opus-4-5-20251101",
          "claude-sonnet-4-5" => "claude-sonnet-4-5-20250929",
          "claude-haiku-4-5" => "claude-haiku-4-5-20251001",
        }.freeze

        def normalize_model_params(model_params)
          model_params = model_params.dup

          if thinking_config.present? && thinking_config.enabled?
            strip_sampling_params_for_thinking!(model_params)
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

        def resolve_thinking_config(model_params)
          effort =
            DiscourseAi::Completions::ThinkingConfig.normalize_effort(
              model_params[:thinking_effort],
            )

          if effort.blank?
            provider_param_config = provider_param_thinking_config(model_params)
            return provider_param_config if provider_param_config
            return DiscourseAi::Completions::ThinkingConfig.disabled
          end

          if !supports_anthropic_thinking?
            return DiscourseAi::Completions::ThinkingConfig.unsupported(canonical_effort: effort)
          end

          return DiscourseAi::Completions::ThinkingConfig.explicit_none if effort == "none"

          if requires_adaptive_thinking?
            total_output_tokens = adaptive_total_output_tokens(model_params)
            return(
              DiscourseAi::Completions::ThinkingConfig.new(
                canonical_effort: effort,
                enabled: true,
                provider_effort: "adaptive",
                # output_config.effort only accepts low/medium/high/xhigh/max —
                # no "minimal" — same collapse as the OpenAI effort scale.
                output_effort: effort == "minimal" ? "low" : effort,
                provider_output_tokens: total_output_tokens,
                reserved_output_tokens: total_output_tokens,
                strip_temperature: true,
                strip_top_p: true,
              )
            )
          end

          budget = THINKING_BUDGETS[effort]
          if budget.blank?
            return DiscourseAi::Completions::ThinkingConfig.unsupported(canonical_effort: effort)
          end

          config =
            budget_thinking_config(
              canonical_effort: effort,
              budget: budget,
              model_params: model_params,
            )
          return config if config

          DiscourseAi::Completions::ThinkingConfig.unsupported(canonical_effort: effort)
        end

        def xml_tags_to_strip(dialect)
          if dialect.prompt.has_tools?
            %w[thinking search_quality_reflection search_quality_score]
          else
            []
          end
        end

        protected

        def output_stop_reason
          processor.stop_reason
        end

        def output_limit_reached?
          processor.output_limit_reached
        end

        def reported_reasoning_tokens
          processor.reasoning_tokens
        end

        private

        def supports_anthropic_thinking?
          true
        end

        def requires_adaptive_thinking?
          llm_model.lookup_custom_param("adaptive_thinking")
        end

        def provider_param_thinking_config(model_params)
          return if !supports_anthropic_thinking?

          if llm_model.lookup_custom_param("adaptive_thinking")
            total_output_tokens = adaptive_total_output_tokens(model_params)
            return(
              DiscourseAi::Completions::ThinkingConfig.new(
                canonical_effort: "adaptive",
                enabled: true,
                provider_effort: "adaptive",
                provider_output_tokens: total_output_tokens,
                reserved_output_tokens: total_output_tokens,
                strip_temperature: true,
                strip_top_p: true,
              )
            )
          end

          if llm_model.lookup_custom_param("enable_reasoning")
            budget = llm_model.lookup_custom_param("reasoning_tokens").to_i.clamp(1024, 32_768)
            config =
              budget_thinking_config(
                canonical_effort: "custom",
                budget: budget,
                model_params: model_params,
              )
            return config if config

            DiscourseAi::Completions::ThinkingConfig.unsupported(canonical_effort: "custom")
          end
        end

        # Canonical Anthropic API name for the configured model, accepting
        # friendly aliases and Bedrock-style IDs (profile prefixes and
        # version suffixes are stripped).
        def canonical_claude_model_name
          raw = llm_model.name.to_s.strip
          return "claude-2.1" if raw.match?(/claude-v2(?::1)?\z/i)
          return "claude-instant-1.2" if raw.match?(/claude-instant-v1\z/i)

          stripped = raw.sub(/\A(?:[a-z]{2,}\.)?anthropic\./i, "").sub(/-v\d+(?::\d+)?\z/i, "")

          CLAUDE_MODEL_ALIASES[stripped.downcase] || stripped
        end

        # Bedrock model ID for the configured model. Already-qualified
        # Bedrock IDs, inference profile IDs and ARNs pass through
        # unchanged, as do non-Claude models.
        def bedrock_model_id
          raw = llm_model.name.to_s.strip
          return raw if raw.start_with?("arn:") || raw.match?(/\A(?:[a-z]{2,}\.)?anthropic\./i)

          canonical = canonical_claude_model_name

          case canonical
          when "claude-2.1"
            "anthropic.claude-v2:1"
          when "claude-instant-1.2"
            "anthropic.claude-instant-v1"
          when "claude-3-5-sonnet-20241022"
            "anthropic.claude-3-5-sonnet-20241022-v2:0"
          when "claude-opus-4-6"
            "anthropic.claude-opus-4-6-v1"
          when /\Aclaude-.+-\d{8}\z/
            "anthropic.#{canonical}-v1:0"
          when /\Aclaude-/
            "anthropic.#{canonical}"
          else
            raw
          end
        end

        def bedrock_provider?
          %w[aws_bedrock aws_bedrock_converse].include?(llm_model.provider)
        end

        # A configured limit always wins. When it is missing we fall back to
        # the known cap for the model, and to a generous assumed cap for
        # models we do not recognise.
        def effective_max_output_tokens
          configured = llm_model.max_output_tokens.to_i
          return configured if configured.positive?

          known_model_max_output_tokens || UNKNOWN_MODEL_MAX_OUTPUT_TOKENS
        end

        def enforce_max_output_tokens(value)
          return super if !supports_anthropic_thinking?

          limit = effective_max_output_tokens
          value = limit if (value.to_i > limit) || (value.to_i <= 0)
          value
        end

        def known_model_max_output_tokens
          name = canonical_claude_model_name.to_s.downcase

          case name
          when /claude-(?:fable|mythos|opus|sonnet|haiku)-5(?:-|\z)/,
               /claude-opus-4-(?:[6-9]|\d{2,})(?:-|\z)/
            128_000
          when /claude-sonnet-4-6(?:-|\z)/
            # Bedrock caps Sonnet 4.6 at 64k; the Anthropic API allows 128k.
            bedrock_provider? ? 64_000 : 128_000
          when /claude-(?:opus|sonnet|haiku)-4-5(?:-|\z)/, /claude-sonnet-4(?:-|\z)/,
               /claude-4-sonnet(?:-|\z)/, /claude-3-7(?:-|\z)/
            64_000
          when /claude-opus-4-1(?:-|\z)/, /claude-opus-4(?:-|\z)/, /claude-4-opus(?:-|\z)/
            32_000
          when /claude-3-5(?:-|\z)/
            8_192
          when /claude-3(?:-|\z)/, /claude-(?:v2|2)(?:[-.:]|\z)/, /claude-instant/
            4_096
          end
        end

        # Prompt admission must reserve what this endpoint can actually
        # send: the explicit ceiling when given, otherwise the effective
        # cap. Thinking configs already reserve their provider total.
        def apply_thinking_config_to_model_params(model_params)
          result = super
          if supports_anthropic_thinking? && result[:reserved_output_tokens].blank?
            result[:reserved_output_tokens] = model_params[:max_tokens].presence ||
              effective_max_output_tokens
          end
          result
        end

        def adaptive_total_output_tokens(model_params)
          requested_output_tokens = model_params[:max_tokens].presence&.to_i
          output_token_limit = effective_max_output_tokens

          if requested_output_tokens&.positive?
            [requested_output_tokens, output_token_limit].min
          else
            output_token_limit
          end
        end

        def budget_thinking_config(canonical_effort:, budget:, model_params:)
          requested_visible_output_tokens = model_params[:max_tokens].presence&.to_i
          output_token_limit = effective_max_output_tokens

          if model_params[:max_tokens_is_total] && requested_visible_output_tokens&.positive?
            provider_output_tokens = requested_visible_output_tokens
            if output_token_limit.positive?
              provider_output_tokens = [provider_output_tokens, output_token_limit].min
            end
            # Budget thinking needs at least 1024 reasoning tokens and some visible output.
            # Small work allocations disable optional thinking instead of inflating the request.
            if provider_output_tokens <= MIN_THINKING_BUDGET
              return DiscourseAi::Completions::ThinkingConfig.explicit_none
            end
            visible_floor = [
              MIN_VISIBLE_OUTPUT_TOKENS,
              provider_output_tokens - MIN_THINKING_BUDGET,
            ].min
            budget = [budget, provider_output_tokens - visible_floor].min
            visible_output_tokens = provider_output_tokens - budget
          elsif output_token_limit.positive?
            return if output_token_limit <= MIN_THINKING_BUDGET

            max_visible_output_tokens = output_token_limit - MIN_THINKING_BUDGET
            visible_output_floor = [MIN_VISIBLE_OUTPUT_TOKENS, max_visible_output_tokens].min

            # The requested thinking budget stays authoritative: visible
            # output and thinking together form the provider total, shrunk
            # only when that total would exceed the effective cap.
            visible_output_tokens =
              if requested_visible_output_tokens&.positive?
                requested_visible_output_tokens
              else
                output_token_limit - budget
              end
            visible_output_tokens = [visible_output_tokens, visible_output_floor].max
            visible_output_tokens = [visible_output_tokens, max_visible_output_tokens].min

            budget = [budget, output_token_limit - visible_output_tokens].min
            return if budget < MIN_THINKING_BUDGET

            provider_output_tokens = visible_output_tokens + budget
          end

          DiscourseAi::Completions::ThinkingConfig.new(
            canonical_effort: canonical_effort,
            enabled: true,
            thinking_token_budget: budget,
            visible_output_tokens: visible_output_tokens,
            provider_output_tokens: provider_output_tokens,
            reserved_output_tokens: provider_output_tokens,
            strip_temperature: true,
            strip_top_p: true,
          )
        end

        def apply_anthropic_effort_config!(options)
          # a per-call thinking_effort that resolved to adaptive mode takes priority
          # over the static admin-configured "effort" param
          return if thinking_config.present? && thinking_config.output_effort.present?

          effort = llm_model.lookup_custom_param("effort")
          options[:output_config] = { effort: effort } if AnthropicShared::EFFORT_VALUES.include?(
            effort,
          )
        end

        def apply_anthropic_thinking_config!(options)
          @thinking_config ||=
            provider_param_thinking_config({}) || DiscourseAi::Completions::ThinkingConfig.disabled
          return if thinking_config.blank? || thinking_config.unsupported?

          if thinking_config.explicit_none?
            options.delete(:thinking)
            return
          end

          if thinking_config.provider_effort == "adaptive"
            options[:thinking] = { type: "adaptive" }
            if thinking_config.output_effort.present?
              options[:output_config] = { effort: thinking_config.output_effort }
            end
          elsif thinking_config.thinking_token_budget
            options[:thinking] = {
              type: "enabled",
              budget_tokens: thinking_config.thinking_token_budget,
            }
          end

          return if thinking_config.provider_output_tokens.blank?

          options[:max_tokens] = thinking_config.provider_output_tokens
        end

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

        def decode_chunk_finish
          processor.finish
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
          apply_anthropic_thinking_config!(payload)

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
