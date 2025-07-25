# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Cohere < Base
        def self.can_contact?(model_provider)
          model_provider == "cohere"
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup
          model_params[:p] = model_params.delete(:top_p) if model_params[:top_p]
          model_params
        end

        def default_options(dialect)
          { model: "command-r-plus" }
        end

        def provider_id
          AiApiAuditLog::Provider::Cohere
        end

        private

        def model_uri
          URI(llm_model.url)
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = default_options(dialect).merge(model_params).merge(prompt)
          if prompt[:tools].present?
            payload[:tools] = prompt[:tools]
            payload[:force_single_step] = false
          end
          payload[:tool_results] = prompt[:tool_results] if prompt[:tool_results].present?
          payload[:stream] = true if @streaming_mode

          payload
        end

        def prepare_request(payload)
          headers = {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{llm_model.api_key}",
          }

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def decode(response_raw)
          rval = []

          parsed = JSON.parse(response_raw, symbolize_names: true)

          text = parsed[:text]
          rval << parsed[:text] if !text.to_s.empty? # also allow " "

          # TODO tool calls

          update_usage(parsed)

          rval
        end

        def decode_chunk(chunk)
          @tool_idx ||= -1
          @json_decoder ||= JsonStreamDecoder.new(line_regex: /^\s*({.*})$/)
          (@json_decoder << chunk)
            .map do |parsed|
              update_usage(parsed)
              rval = []

              rval << parsed[:text] if !parsed[:text].to_s.empty?

              if tool_calls = parsed[:tool_calls]
                tool_calls&.each do |tool_call|
                  @tool_idx += 1
                  tool_name = tool_call[:name]
                  tool_params = tool_call[:parameters]
                  tool_id = "tool_#{@tool_idx}"
                  rval << ToolCall.new(id: tool_id, name: tool_name, parameters: tool_params)
                end
              end

              rval
            end
            .flatten
            .compact
        end

        def extract_completion_from(response_raw)
          parsed = JSON.parse(response_raw, symbolize_names: true)

          if @streaming_mode
            if parsed[:event_type] == "text-generation"
              parsed[:text]
            elsif parsed[:event_type] == "tool-calls-generation"
              # could just be random thinking...
              if parsed.dig(:tool_calls).present?
                @has_tool = true
                parsed.dig(:tool_calls).to_json
              else
                ""
              end
            else
              if parsed[:event_type] == "stream-end"
                @input_tokens = parsed.dig(:response, :meta, :billed_units, :input_tokens)
                @output_tokens = parsed.dig(:response, :meta, :billed_units, :output_tokens)
              end
              nil
            end
          else
            @input_tokens = parsed.dig(:meta, :billed_units, :input_tokens)
            @output_tokens = parsed.dig(:meta, :billed_units, :output_tokens)
            parsed[:text].to_s
          end
        end

        def xml_tools_enabled?
          false
        end

        def final_log_update(log)
          log.request_tokens = @input_tokens if @input_tokens
          log.response_tokens = @output_tokens if @output_tokens
        end

        def extract_prompt_for_tokenizer(prompt)
          text = +""
          if prompt[:chat_history]
            text << prompt[:chat_history]
              .map { |message| message[:content] || message["content"] || "" }
              .join("\n")
          end

          text << prompt[:message] if prompt[:message]
          text << prompt[:preamble] if prompt[:preamble]

          text
        end

        private

        def update_usage(parsed)
          input_tokens = parsed.dig(:meta, :billed_units, :input_tokens)
          input_tokens ||= parsed.dig(:response, :meta, :billed_units, :input_tokens)
          @input_tokens = input_tokens if input_tokens.present?

          output_tokens = parsed.dig(:meta, :billed_units, :output_tokens)
          output_tokens ||= parsed.dig(:response, :meta, :billed_units, :output_tokens)
          @output_tokens = output_tokens if output_tokens.present?
        end
      end
    end
  end
end
