# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Vllm < OpenAi
        ENABLE_THINKING_PARSERS = %w[qwen3 gemma4 deepseek_v4].freeze
        THINKING_PARSERS = %w[granite deepseek_v3 holo2].freeze
        VLLM_REASONING_EFFORTS = %w[none low medium high].freeze
        VLLM_REASONING_EFFORT_BY_CANONICAL = {
          "none" => "none",
          "minimal" => "low",
          "low" => "low",
          "medium" => "medium",
          "high" => "high",
          "xhigh" => "high",
          "max" => "high",
        }.freeze

        def self.can_contact?(llm_model)
          llm_model.provider == "vllm"
        end

        def provider_id
          AiApiAuditLog::Provider::Vllm
        end

        def decode(response_raw)
          parsed = JSON.parse(response_raw, symbolize_names: true)
          result = processor.process_message(parsed)

          if output_thinking
            reasoning = parsed.dig(:choices, 0, :message, :reasoning).presence
            reasoning ||= parsed.dig(:choices, 0, :message, :reasoning_content)
            result.unshift(Thinking.new(message: reasoning)) if reasoning.present?
          end

          result
        end

        def decode_chunk(chunk)
          @decoder ||= JsonStreamDecoder.new

          elements = []
          (@decoder << chunk).each do |parsed_json|
            if output_thinking
              reasoning = parsed_json.dig(:choices, 0, :delta, :reasoning).presence
              reasoning ||= parsed_json.dig(:choices, 0, :delta, :reasoning_content)
              if reasoning.present?
                if @thinking.nil?
                  @thinking = Thinking.new(message: reasoning.dup, partial: true)
                else
                  @thinking.message << reasoning
                end
                elements << Thinking.new(message: reasoning, partial: true)
              elsif @thinking
                @thinking.partial = false
                elements << @thinking
                @thinking = nil
              end
            end

            result = processor.process_streamed_message(parsed_json)
            elements << result if result
          end

          elements = elements.flatten.compact

          seen_tools = Set.new
          elements.select { |item| !item.is_a?(ToolCall) || seen_tools.add?(item) }
        end

        def decode_chunk_finish
          result = []
          if @thinking
            @thinking.partial = false
            result << @thinking
            @thinking = nil
          end
          result.concat(processor.finish)
        end

        def resolve_thinking_config(model_params)
          effort =
            DiscourseAi::Completions::ThinkingConfig.normalize_effort(
              model_params[:thinking_effort],
            )

          if effort.present?
            provider_effort = VLLM_REASONING_EFFORT_BY_CANONICAL[effort]
          else
            provider_effort = raw_custom_param("reasoning_effort")
            effort = provider_effort
          end

          return DiscourseAi::Completions::ThinkingConfig.disabled if effort.blank?

          if provider_effort.blank? || !VLLM_REASONING_EFFORTS.include?(provider_effort)
            return DiscourseAi::Completions::ThinkingConfig.unsupported(canonical_effort: effort)
          end

          DiscourseAi::Completions::ThinkingConfig.new(
            canonical_effort: effort,
            provider_effort: provider_effort,
            enabled: provider_effort != "none",
            explicit_none: provider_effort == "none",
            strip_temperature: provider_effort != "none",
            strip_top_p: provider_effort != "none",
          )
        end

        private

        def prepare_payload(prompt, model_params, dialect)
          payload = super

          if @streaming_mode && !payload.key?(:stream_options)
            payload[:stream_options] = { include_usage: true }
          end

          apply_thinking_template_kwargs(payload)
          apply_thinking_token_budget(payload)

          payload
        end

        def apply_thinking_template_kwargs(payload)
          template_kwargs = thinking_template_kwargs
          return if template_kwargs.blank?

          payload[:chat_template_kwargs] ||= {}
          payload[:chat_template_kwargs].merge!(template_kwargs)
        end

        def thinking_template_kwargs
          override = active_custom_param("thinking_override")

          if override
            return {} if !%w[on off].include?(override)

            parser = active_custom_param("reasoning_parser")
            thinking_enabled = override == "on"

            if ENABLE_THINKING_PARSERS.include?(parser)
              { enable_thinking: thinking_enabled }
            elsif THINKING_PARSERS.include?(parser)
              { thinking: thinking_enabled }
            else
              {}
            end
          elsif llm_model.lookup_custom_param("enable_thinking")
            { enable_thinking: true }
          else
            {}
          end
        end

        def apply_thinking_token_budget(payload)
          return if active_custom_param("reasoning_parser").blank?
          return if reasoning_effort == "none"

          budget = llm_model.lookup_custom_param("thinking_token_budget").to_i
          payload[:thinking_token_budget] = budget if budget.positive?
        end

        def active_custom_param(key)
          value = llm_model.lookup_custom_param(key)
          value = value.strip if value.respond_to?(:strip)
          return nil if value.blank? || value == "default"

          value
        end

        def reasoning_effort
          thinking_config&.provider_effort
        end

        def raw_custom_param(key)
          value = llm_model.provider_params&.dig(key) || llm_model.provider_params&.dig(key.to_sym)
          value = value.strip if value.respond_to?(:strip)
          return nil if value.blank? || value == "default"

          value
        end

        def prepare_request(payload)
          headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }

          api_key = llm_model&.api_key || SiteSetting.ai_vllm_api_key
          headers["Authorization"] = "Bearer #{api_key}" if api_key.present?

          headers.merge!(extra_request_headers)

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end
      end
    end
  end
end
