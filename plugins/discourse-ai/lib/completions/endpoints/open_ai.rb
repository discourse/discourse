# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class OpenAi < Base
        include OpenAiShared

        def self.can_contact?(llm_model)
          %w[open_ai azure groq].include?(llm_model.provider) &&
            !llm_model.url.to_s.include?("/v1/responses")
        end

        def normalize_model_params(model_params)
          normalized = super

          # max_tokens is deprecated however we still need to support it
          # on older OpenAI models and older Azure models, so we will only normalize
          # if our model name starts with o (to denote all the reasoning models)
          if llm_model.name.starts_with?(/o|gpt-5/)
            max_tokens = normalized.delete(:max_tokens)
            normalized[:max_completion_tokens] = max_tokens if max_tokens
          end

          normalized
        end

        private

        def srv_fallback_path
          "/v1/chat/completions"
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = default_options.merge(model_params).merge(messages: prompt)

          payload.merge!({ reasoning_effort: reasoning_effort }) if reasoning_effort
          payload[:service_tier] = service_tier if service_tier

          if @streaming_mode
            payload[:stream] = true

            # Usage is not available in Azure yet.
            # We'll fallback to guess this using the tokenizer.
            payload[:stream_options] = { include_usage: true } if llm_model.provider == "open_ai"
          end

          if !xml_tools_enabled?
            if dialect.tools.present?
              payload[:tools] = dialect.tools
              if dialect.tool_choice.present?
                if dialect.tool_choice == :none
                  payload[:tool_choice] = "none"
                else
                  payload[:tool_choice] = {
                    type: "function",
                    function: {
                      name: dialect.tool_choice,
                    },
                  }
                end
              end
            end
          end

          payload
        end

        def processor
          @processor ||= OpenAiMessageProcessor.new(partial_tool_calls: partial_tool_calls)
        end
      end
    end
  end
end
