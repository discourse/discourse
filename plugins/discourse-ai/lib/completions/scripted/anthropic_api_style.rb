# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class AnthropicApiStyle < BaseStyle
        def self.can_handle?(llm_model)
          llm_model.provider == "anthropic"
        end

        private

        def build_response(request)
          @response_id = nil
          super
        end

        def streaming_request?(_request, payload)
          !!payload[:stream]
        end

        def normalize_tool_call(tool_hash)
          name = tool_hash[:name]
          raise ArgumentError, "tool_call hash must include :name" if name.blank?

          id = tool_hash[:id] || "toolu_#{SecureRandom.hex(8)}"
          raw_arguments = tool_hash[:arguments] || tool_hash[:input] || {}

          arguments =
            case raw_arguments
            when String
              JSON.parse(raw_arguments, symbolize_names: true)
            when Hash
              raw_arguments.deep_symbolize_keys
            else
              raw_arguments
            end

          { id: id, name: name, arguments: arguments }
        end

        def render_standard_message(response, payload)
          content = response[:content].to_s
          usage = response[:usage] || usage_for_text(content, payload)

          message = base_message(payload)
          message[:content] = [{ type: "text", text: content }]
          message[:stop_reason] = "end_turn"
          message[:usage] = usage

          Response.new(body: message.to_json)
        end

        def render_standard_tool_calls(response, payload)
          tool_calls = response[:tool_calls]
          usage = response[:usage] || usage_for_tool_calls(tool_calls, payload)

          blocks = []
          if response[:message_content].present?
            blocks << { type: "text", text: response[:message_content].to_s }
          end

          tool_calls.each do |tool|
            blocks << {
              type: "tool_use",
              id: tool[:id],
              name: tool[:name],
              input: tool[:arguments],
            }
          end

          message = base_message(payload)
          message[:content] = blocks
          message[:stop_reason] = "tool_use"
          message[:usage] = usage

          Response.new(body: message.to_json)
        end

        def render_streaming_message(response, payload)
          content = response[:content].to_s
          usage = response[:usage] || usage_for_text(content, payload)
          chunks = []

          chunks << event_chunk("message_start", message: streaming_message_header(payload, usage))
          chunks << event_chunk(
            "content_block_start",
            index: 0,
            content_block: {
              type: "text",
              text: "",
            },
          )

          stream_chunks_for(content).each do |piece|
            chunks << event_chunk(
              "content_block_delta",
              index: 0,
              delta: {
                type: "text_delta",
                text: piece,
              },
            )
          end

          chunks << event_chunk("content_block_stop", index: 0)
          chunks << event_chunk(
            "message_delta",
            delta: {
              stop_reason: "end_turn",
              stop_sequence: nil,
            },
            usage: {
              output_tokens: usage[:output_tokens],
            },
          )
          chunks << event_chunk("message_stop")

          Response.new(chunks: chunks)
        end

        def render_streaming_tool_calls(response, payload)
          tool_calls = response[:tool_calls]
          usage = response[:usage] || usage_for_tool_calls(tool_calls, payload)
          chunks = []

          chunks << event_chunk("message_start", message: streaming_message_header(payload, usage))

          index = 0
          if response[:message_content].present?
            chunks.concat(stream_text_block(index, response[:message_content].to_s))
            index += 1
          end

          tool_calls.each do |tool|
            chunks << event_chunk(
              "content_block_start",
              index: index,
              content_block: {
                type: "tool_use",
                id: tool[:id],
                name: tool[:name],
                input: {
                },
              },
            )

            stream_chunks_for(JSON.generate(tool[:arguments], quirks_mode: true)).each do |piece|
              chunks << event_chunk(
                "content_block_delta",
                index: index,
                delta: {
                  type: "input_json_delta",
                  partial_json: piece,
                },
              )
            end

            chunks << event_chunk("content_block_stop", index: index)
            index += 1
          end

          chunks << event_chunk(
            "message_delta",
            delta: {
              stop_reason: "tool_use",
              stop_sequence: nil,
            },
            usage: {
              output_tokens: usage[:output_tokens],
            },
          )
          chunks << event_chunk("message_stop")

          Response.new(chunks: chunks)
        end

        def stream_text_block(index, text)
          chunks = []

          chunks << event_chunk(
            "content_block_start",
            index: index,
            content_block: {
              type: "text",
              text: "",
            },
          )

          stream_chunks_for(text).each do |piece|
            chunks << event_chunk(
              "content_block_delta",
              index: index,
              delta: {
                type: "text_delta",
                text: piece,
              },
            )
          end

          chunks << event_chunk("content_block_stop", index: index)
          chunks
        end

        def streaming_message_header(payload, usage)
          message = base_message(payload)
          message[:content] = []
          message[:usage] = { input_tokens: usage[:input_tokens], output_tokens: 0 }
          message[:stop_reason] = nil
          message[:stop_sequence] = nil
          message
        end

        def event_chunk(event, data = {})
          payload = { type: event }.merge(data)
          "event: #{event}\n" + "data: #{payload.to_json}\n\n"
        end

        def base_message(payload)
          {
            id: response_id,
            type: "message",
            role: "assistant",
            model: payload[:model] || llm_model.name,
            content: [],
          }
        end

        def usage_for_text(content, payload)
          {
            input_tokens: prompt_token_estimate(payload),
            output_tokens: llm_model.tokenizer_class.size(content),
          }
        end

        def usage_for_tool_calls(tool_calls, payload)
          arguments_text =
            tool_calls.map { |tool| JSON.generate(tool[:arguments], quirks_mode: true) }.join

          {
            input_tokens: prompt_token_estimate(payload),
            output_tokens: llm_model.tokenizer_class.size(arguments_text),
          }
        end

        def prompt_token_estimate(payload)
          parts = []
          parts << payload[:system].to_s if payload[:system].present?

          Array(payload[:messages]).each do |message|
            content = message[:content]
            parts << stringify_message_content(content)
          end

          llm_model.tokenizer_class.size(parts.join)
        end

        def stringify_message_content(content)
          case content
          when String
            content
          when Array
            content
              .map do |element|
                if element.is_a?(Hash)
                  element[:text] || element[:thinking] || element[:data] ||
                    (
                      if element[:input]
                        JSON.generate(element[:input], quirks_mode: true)
                      else
                        element.to_json
                      end
                    )
                else
                  element.to_s
                end
              end
              .join
          when Hash
            content.to_json
          else
            content.to_s
          end
        end

        def response_id
          @response_id ||= "scripted-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
