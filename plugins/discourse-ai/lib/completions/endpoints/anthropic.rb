# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Anthropic < Base
        include AnthropicPromptCache
        include AnthropicShared

        def self.can_contact?(llm_model)
          llm_model.provider == "anthropic"
        end

        def default_options(dialect)
          mapped_model = canonical_claude_model_name

          # Note: Anthropic requires this param
          options = { model: mapped_model, max_tokens: effective_max_output_tokens }
          apply_anthropic_thinking_config!(options)
          apply_anthropic_effort_config!(options)

          options[:stop_sequences] = ["</function_calls>"] if !dialect.native_tool_support? &&
            dialect.prompt.has_tools?

          options
        end

        private

        def model_uri
          URI(llm_model.url)
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = prepare_claude_payload(prompt, model_params, dialect)
          payload[:stream] = true if @streaming_mode
          payload
        end

        def prepare_request(payload)
          headers = {
            "anthropic-version" => "2023-06-01",
            "x-api-key" => llm_model.api_key,
            "content-type" => "application/json",
          }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def decode_chunk(partial_data)
          @decoder ||= JsonStreamDecoder.new
          (@decoder << partial_data)
            .map { |parsed_json| processor.process_streamed_message(parsed_json) }
            .compact
        end

        def processor
          claude_processor
        end

        def final_log_update(log)
          update_log_from_claude_processor(log)
        end
      end
    end
  end
end
