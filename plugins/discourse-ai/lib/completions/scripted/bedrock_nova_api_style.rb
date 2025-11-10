# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class BedrockNovaApiStyle < BaseStyle
        def self.can_handle?(llm_model)
          llm_model.provider == "aws_bedrock" && llm_model.name.to_s.include?("amazon.nova")
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

        def normalize_tool_call(tool_hash)
          name = tool_hash[:name]
          raise ArgumentError, "tool_call hash must include :name" if name.blank?

          {
            id: tool_hash[:id] || SecureRandom.uuid,
            name: name,
            arguments: normalize_arguments(tool_hash[:arguments]),
          }
        end

        def render_standard_message(response, payload)
          content = response[:content].to_s
          usage = response[:usage] || usage_for_text(content, payload)

          Response.new(
            body:
              standard_body(
                text_blocks: [content],
                usage: usage,
                stop_reason: response[:stop_reason],
              ).to_json,
          )
        end

        def render_standard_tool_calls(response, payload)
          usage = response[:usage] || usage_for_tool_calls(response[:tool_calls], payload)

          tool_blocks =
            response[:tool_calls].map do |tool|
              {
                "toolUse" => {
                  "toolUseId" => tool[:id],
                  "name" => tool[:name],
                  "input" => tool[:arguments],
                },
              }
            end

          Response.new(
            body:
              standard_body(
                content_blocks: tool_blocks,
                usage: usage,
                stop_reason: response[:stop_reason],
              ).to_json,
          )
        end

        def render_streaming_message(response, payload)
          content = response[:content].to_s
          usage = response[:usage] || usage_for_text(content, payload)
          chunks = []

          chunks << encode_event_stream({ messageStart: { role: "assistant" } })

          stream_chunks_for(content).each_with_index do |piece, index|
            chunks << encode_event_stream(
              { contentBlockDelta: { delta: { text: piece }, contentBlockIndex: index } },
            )
            chunks << encode_event_stream({ contentBlockStop: { contentBlockIndex: index } })
          end

          chunks << encode_event_stream(
            { messageStop: { stopReason: response[:stop_reason] || "end_turn" } },
          )
          chunks << encode_event_stream(metadata_event(usage))

          Response.new(chunks: chunks)
        end

        def render_streaming_tool_calls(response, payload)
          tool_calls = response[:tool_calls]
          usage = response[:usage] || usage_for_tool_calls(tool_calls, payload)
          chunks = []

          chunks << encode_event_stream({ messageStart: { role: "assistant" } })

          tool_calls.each_with_index do |tool, index|
            chunks << encode_event_stream(
              {
                contentBlockStart: {
                  start: {
                    toolUse: {
                      toolUseId: tool[:id],
                      name: tool[:name],
                    },
                  },
                  contentBlockIndex: index,
                },
              },
            )

            stream_chunks_for(tool_arguments_json(tool[:arguments])).each do |piece|
              chunks << encode_event_stream(
                {
                  contentBlockDelta: {
                    delta: {
                      toolUse: {
                        input: piece,
                      },
                    },
                    contentBlockIndex: index,
                  },
                },
              )
            end

            chunks << encode_event_stream({ contentBlockStop: { contentBlockIndex: index } })
          end

          chunks << encode_event_stream(
            { messageStop: { stopReason: response[:stop_reason] || "tool_use" } },
          )
          chunks << encode_event_stream(metadata_event(usage))

          Response.new(chunks: chunks)
        end

        def standard_body(text_blocks: nil, content_blocks: nil, usage:, stop_reason: nil)
          content =
            if text_blocks
              text_blocks.map { |text| { "text" => text } }
            else
              content_blocks
            end

          {
            "output" => {
              "message" => {
                "content" => content,
                "role" => "assistant",
              },
            },
            "stopReason" => stop_reason || "end_turn",
            "usage" => usage,
          }
        end

        def usage_for_text(content, payload)
          completion_tokens = llm_model.tokenizer_class.size(content)
          prompt_tokens = prompt_token_estimate(payload)

          format_usage(prompt_tokens, completion_tokens)
        end

        def usage_for_tool_calls(tool_calls, payload)
          arguments_text = tool_calls.map { |tool| tool_arguments_json(tool[:arguments]) }.join

          completion_tokens = llm_model.tokenizer_class.size(arguments_text)
          prompt_tokens = prompt_token_estimate(payload)

          format_usage(prompt_tokens, completion_tokens)
        end

        def prompt_token_estimate(payload)
          payload ||= {}
          parts = []
          Array(payload[:system]).each { |entry| parts << entry[:text].to_s }

          Array(payload[:messages]).each do |message|
            Array(message[:content]).each { |block| parts << block[:text].to_s if block[:text] }
          end

          llm_model.tokenizer_class.size(parts.join)
        end

        def format_usage(prompt_tokens, completion_tokens)
          total = prompt_tokens + completion_tokens
          {
            "inputTokens" => prompt_tokens,
            "outputTokens" => completion_tokens,
            "totalTokens" => total,
          }
        end

        def metadata_event(usage)
          usage = (usage || {}).stringify_keys
          {
            metadata: {
              usage: usage.slice("inputTokens", "outputTokens"),
              metrics: {
              },
              trace: {
              },
            },
            "amazon-bedrock-invocationMetrics": {
              inputTokenCount: usage["inputTokens"],
              outputTokenCount: usage["outputTokens"],
              invocationLatency: 0,
              firstByteLatency: 0,
            },
          }
        end

        def normalize_arguments(raw)
          return {} if raw.nil?
          return raw if raw.is_a?(Hash)

          JSON.parse(raw)
        rescue JSON::ParserError
          raw
        end

        def tool_arguments_json(arguments)
          if arguments.is_a?(String)
            arguments
          else
            JSON.generate(arguments || {}, quirks_mode: true)
          end
        end
      end
    end
  end
end
