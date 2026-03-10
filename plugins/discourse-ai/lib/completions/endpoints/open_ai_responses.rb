# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class OpenAiResponses < Base
        include OpenAiShared

        def self.can_contact?(llm_model)
          %w[open_ai azure].include?(llm_model.provider) &&
            llm_model.url.to_s.include?("/v1/responses")
        end

        private

        def srv_fallback_path
          "/v1/responses"
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = default_options.merge(model_params).merge(messages: prompt)

          reasoning_payload = { summary: "auto" }
          reasoning_payload[:effort] = reasoning_effort if reasoning_effort
          payload.merge!(reasoning: reasoning_payload)
          payload[:service_tier] = service_tier if service_tier

          if @streaming_mode
            payload[:stream] = true
            payload[:stream_options] = { include_usage: true } if llm_model.provider == "open_ai"
          end

          if !xml_tools_enabled?
            if dialect.tools.present?
              payload[:tools] = dialect.tools
              if dialect.tool_choice.present?
                if dialect.tool_choice == :none
                  payload[:tool_choice] = "none"
                else
                  payload[:tool_choice] = { type: "function", name: dialect.tool_choice }
                end
              end
            end
          end

          convert_payload_to_responses_api!(payload)
          payload[:include] ||= []
          payload[:include] << "reasoning.encrypted_content"

          payload
        end

        def convert_payload_to_responses_api!(payload)
          payload[:input] = payload.delete(:messages)
          completion_tokens = payload.delete(:max_completion_tokens) || payload.delete(:max_tokens)
          payload[:max_output_tokens] = completion_tokens if completion_tokens

          if payload[:response_format]
            format = payload.delete(:response_format)
            if format && format[:json_schema]
              payload[:text] ||= {}
              payload[:text][:format] = format[:json_schema]
              payload[:text][:format][:type] ||= "json_schema"
            end
          end

          payload.delete(:stream_options)
        end

        def processor
          @processor ||=
            OpenAiResponsesMessageProcessor.new(
              partial_tool_calls: partial_tool_calls,
              output_thinking: output_thinking,
            )
        end
      end
    end
  end
end
