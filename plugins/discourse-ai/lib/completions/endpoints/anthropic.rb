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

          # effort parameter
          effort = llm_model.lookup_custom_param("effort")
          options[:output_config] = { effort: effort } if %w[low medium high].include?(effort)

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
