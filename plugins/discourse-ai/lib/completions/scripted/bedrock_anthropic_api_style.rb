# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class BedrockAnthropicApiStyle < AnthropicApiStyle
        def self.can_handle?(llm_model)
          llm_model.provider == "aws_bedrock" && !llm_model.name.to_s.include?("amazon.nova")
        end

        private

        def encode_event_stream(payload)
          wrapped = { bytes: Base64.strict_encode64(payload.to_json) }.to_json
          Aws::EventStream::Encoder.new.encode(
            Aws::EventStream::Message.new(payload: StringIO.new(wrapped)),
          )
        end

        def streaming_request?(request, _payload)
          request.path&.include?("invoke-with-response-stream")
        end

        def render_streaming_message(response, payload)
          usage = usage_for_streaming_message(response, payload)
          wrap_streaming_response(super, usage)
        end

        def render_streaming_tool_calls(response, payload)
          usage = response[:usage] || usage_for_tool_calls(response[:tool_calls], payload)
          wrap_streaming_response(super, usage)
        end

        def usage_for_streaming_message(response, payload)
          content_blocks = symbolized_content_blocks(response[:content_blocks])

          if response[:usage]
            response[:usage]
          elsif content_blocks.present?
            usage_for_content_blocks(content_blocks, payload)
          else
            usage_for_text(response[:content].to_s, payload)
          end
        end

        def wrap_streaming_response(response, usage)
          chunks = []

          response.read_body do |chunk|
            event_name, data = parse_sse_chunk(chunk)
            next if event_name.blank? || data.blank?

            payload = JSON.parse(data)
            if event_name == "message_stop" && usage
              payload["amazon-bedrock-invocationMetrics"] = bedrock_metrics(usage)
            end
            chunks << encode_event_stream(payload)
          end

          Response.new(chunks: chunks)
        end

        def parse_sse_chunk(chunk)
          event = nil
          data = nil

          chunk.each_line do |line|
            if line.start_with?("event:")
              event = line.split("event:").last.strip
            elsif line.start_with?("data:")
              data = line.split("data:").last.strip
            end
          end

          [event, data]
        end

        def bedrock_metrics(usage)
          {
            "inputTokenCount" => usage[:input_tokens],
            "outputTokenCount" => usage[:output_tokens],
            "invocationLatency" => 0,
            "firstByteLatency" => 0,
          }.compact
        end
      end
    end
  end
end
