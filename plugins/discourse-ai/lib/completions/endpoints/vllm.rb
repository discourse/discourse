# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Vllm < OpenAi
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
            reasoning = parsed.dig(:choices, 0, :message, :reasoning_content)
            result.unshift(Thinking.new(message: reasoning)) if reasoning.present?
          end

          result
        end

        def decode_chunk(chunk)
          @decoder ||= JsonStreamDecoder.new

          elements = []
          (@decoder << chunk).each do |parsed_json|
            if output_thinking
              reasoning = parsed_json.dig(:choices, 0, :delta, :reasoning_content)
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

        private

        def prepare_payload(prompt, model_params, dialect)
          payload = super

          if @streaming_mode && !payload.key?(:stream_options)
            payload[:stream_options] = { include_usage: true }
          end

          if llm_model.lookup_custom_param("enable_thinking")
            payload[:chat_template_kwargs] = { enable_thinking: true }
          end

          payload
        end

        def prepare_request(payload)
          headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }

          api_key = llm_model&.api_key || SiteSetting.ai_vllm_api_key
          headers["X-API-KEY"] = api_key if api_key.present?

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end
      end
    end
  end
end
