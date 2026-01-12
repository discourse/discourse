# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class CannedResponse
        CANNED_RESPONSE_ERROR = Class.new(StandardError)

        def initialize(responses)
          @responses = responses
          @completions = 0
          @dialect = nil
        end

        def normalize_model_params(model_params)
          # max_tokens, temperature, stop_sequences are already supported
          model_params
        end

        attr_reader :responses, :completions, :dialect, :model_params

        def prompt_messages
          dialect.prompt.messages
        end

        def perform_completion!(
          dialect,
          _user,
          model_params,
          feature_name: nil,
          feature_context: nil,
          partial_tool_calls: false,
          output_thinking: false,
          cancel_manager: nil
        )
          @dialect = dialect
          @model_params = model_params
          response = responses[completions]
          if response.nil?
            raise CANNED_RESPONSE_ERROR,
                  "The number of completions you requested exceed the number of canned responses"
          end

          raise response if response.is_a?(StandardError)

          @completions += 1
          response_enum = response.is_a?(Array) ? response : [response]
          if block_given?
            cancelled = false
            cancel_fn = lambda { cancelled = true }

            response_enum.each do |chunk|
              handle_response_chunk(chunk, cancel_fn) { |val| yield(val, cancel_fn) if !cancelled }
            end
          end

          final_response =
            if model_params[:response_format].present?
              aggregate_structured_response(response_enum)
            else
              response_enum.length == 1 ? response_enum.first : response_enum
            end

          final_response
        end

        def tokenizer
          DiscourseAi::Tokenizer::OpenAiTokenizer
        end

        private

        def handle_response_chunk(chunk, cancel_fn)
          if is_tool?(chunk)
            yield chunk
          elsif is_thinking?(chunk)
            yield chunk
          elsif model_params[:response_format].present?
            structured =
              (
                if chunk.is_a?(DiscourseAi::Completions::StructuredOutput)
                  chunk
                else
                  as_structured_output(chunk)
                end
              )
            yield structured
          else
            chunk.to_s.each_char { |char| yield char }
          end
        end

        def aggregate_structured_response(response_enum)
          schema_properties = model_params[:response_format].dig(:json_schema, :schema, :properties)

          return response_enum.first if schema_properties.blank?

          output = DiscourseAi::Completions::StructuredOutput.new(schema_properties)

          response_enum.each do |chunk|
            structured =
              if chunk.is_a?(DiscourseAi::Completions::StructuredOutput)
                chunk
              else
                as_structured_output(chunk)
              end
            output << structured.to_s
          end

          output.finish
          output
        end

        def is_thinking?(response)
          response.is_a?(DiscourseAi::Completions::Thinking)
        end

        def is_tool?(response)
          response.is_a?(DiscourseAi::Completions::ToolCall)
        end

        def as_structured_output(response)
          schema_properties = model_params[:response_format].dig(:json_schema, :schema, :properties)
          return response if schema_properties.blank?

          parsed = parse_structured_response(response)

          payload =
            if parsed.is_a?(Hash)
              parsed = parsed.stringify_keys
              schema_properties
                .keys
                .each_with_object({}) do |key, memo|
                  string_key = key.to_s
                  memo[key] = parsed[string_key] if parsed.key?(string_key)
                end
            else
              { schema_properties.keys.first => response }
            end

          output = DiscourseAi::Completions::StructuredOutput.new(schema_properties)
          output << payload.to_json
          output.finish

          output
        end

        def parse_structured_response(response)
          case response
          when Hash
            response
          when String
            JSON.parse(response)
          else
            nil
          end
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
