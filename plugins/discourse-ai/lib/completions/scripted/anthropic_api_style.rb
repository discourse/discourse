# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class AnthropicApiStyle < BaseStyle
        def self.can_handle?(llm_model)
          llm_model.provider == "anthropic"
        end

        private

        def normalize_hash_response(response)
          if response.key?(:content_blocks)
            blocks = Array.wrap(response[:content_blocks])
            raise ArgumentError, "content_blocks array cannot be empty" if blocks.blank?

            normalized = { type: :message, content_blocks: blocks }
            usage = response[:usage]
            normalized[:usage] = usage if usage
            return normalized
          end

          normalized = super(response)

          if normalized[:type] == :tool_calls && response.key?(:content)
            normalized[:message_content] = response[:content]
          end

          normalized
        end

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
          content_blocks = symbolized_content_blocks(response[:content_blocks])
          usage =
            if response[:usage]
              response[:usage]
            elsif content_blocks.present?
              usage_for_content_blocks(content_blocks, payload)
            else
              usage_for_text(response[:content].to_s, payload)
            end

          message = base_message(payload)
          if content_blocks.present?
            message[:content] = format_content_blocks(content_blocks)
          else
            message[:content] = [{ type: "text", text: response[:content].to_s }]
          end
          message[:stop_reason] = response[:stop_reason] || "end_turn"
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
          content_blocks = symbolized_content_blocks(response[:content_blocks])

          if content_blocks.present?
            usage = response[:usage] || usage_for_content_blocks(content_blocks, payload)
            stop_reason = response[:stop_reason] || "end_turn"
            chunks = stream_content_blocks(content_blocks, payload, usage, stop_reason)
            return Response.new(chunks: chunks)
          end

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
          delta_payload = { stop_reason: "end_turn", stop_sequence: nil }
          event_payload = { delta: delta_payload }
          event_payload[:usage] = { output_tokens: usage[:output_tokens] } if usage[:output_tokens]
          chunks << event_chunk("message_delta", event_payload)
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

        def stream_text_block(index, text, chunks_override: nil)
          chunks = []

          chunks << event_chunk(
            "content_block_start",
            index: index,
            content_block: {
              type: "text",
              text: "",
            },
          )

          (chunks_override || stream_chunks_for(text)).each do |piece|
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

          if usage
            message[:usage] = {}
            message[:usage][:input_tokens] = usage[:input_tokens] if usage[:input_tokens]
            message[:usage][:output_tokens] = 0
          end

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

        def usage_for_content_blocks(blocks, payload)
          {
            input_tokens: prompt_token_estimate(payload),
            output_tokens: llm_model.tokenizer_class.size(content_blocks_text(blocks)),
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

        def content_blocks_text(blocks)
          blocks
            .to_a
            .map do |block|
              block = block.deep_symbolize_keys
              case block[:type].to_s
              when "thinking"
                block[:thinking].to_s
              when "text"
                block[:text].to_s
              else
                ""
              end
            end
            .join
        end

        def symbolized_content_blocks(blocks)
          return [] if blocks.blank?

          Array.wrap(blocks).map { |block| block.deep_symbolize_keys }
        end

        def format_content_blocks(blocks)
          blocks.map { |block| formatted_content_block(block) }
        end

        def formatted_content_block(block)
          case block[:type].to_s
          when "thinking"
            payload = { type: "thinking", thinking: block[:thinking].to_s }
            payload[:signature] = block[:signature].to_s if block[:signature]
            payload
          when "redacted_thinking"
            { type: "redacted_thinking", data: block[:data].to_s }
          when "text"
            { type: "text", text: block[:text].to_s }
          when "tool_use"
            raise ArgumentError, "tool_use content block must include :name" if block[:name].blank?
            {
              type: "tool_use",
              id: block[:id] || "toolu_#{SecureRandom.hex(6)}",
              name: block[:name],
              input: block[:input] || block[:arguments] || {},
            }
          else
            raise ArgumentError, "Unsupported Anthropic content block #{block[:type]}"
          end
        end

        def stream_content_blocks(blocks, payload, usage, stop_reason)
          chunks = []
          chunks << event_chunk("message_start", message: streaming_message_header(payload, usage))

          blocks.each_with_index do |block, index|
            case block[:type].to_s
            when "thinking"
              chunks.concat(stream_thinking_block(index, block))
            when "redacted_thinking"
              chunks << event_chunk(
                "content_block_start",
                index: index,
                content_block: {
                  type: "redacted_thinking",
                  data: block[:data].to_s,
                },
              )
              chunks << event_chunk("content_block_stop", index: index)
            when "text"
              chunks.concat(
                stream_text_block(index, block[:text].to_s, chunks_override: block[:text_chunks]),
              )
            else
              raise ArgumentError, "Unsupported streaming content block #{block[:type]}"
            end
          end

          delta_payload = { stop_reason: stop_reason, stop_sequence: nil }
          event_payload = { delta: delta_payload }
          if usage && usage[:output_tokens]
            event_payload[:usage] = { output_tokens: usage[:output_tokens] }
          end

          chunks << event_chunk("message_delta", event_payload)
          chunks << event_chunk("message_stop")
          chunks
        end

        def stream_thinking_block(index, block)
          chunks = []

          chunks << event_chunk(
            "content_block_start",
            index: index,
            content_block: {
              type: "thinking",
              thinking: "",
            },
          )

          thinking_chunks = block[:thinking_chunks] || stream_chunks_for(block[:thinking].to_s)
          thinking_chunks.each do |piece|
            chunks << event_chunk(
              "content_block_delta",
              index: index,
              delta: {
                type: "thinking_delta",
                thinking: piece,
              },
            )
          end

          signature_chunks = block[:signature_chunks]
          if signature_chunks.blank? && block[:signature]
            signature_chunks = [block[:signature].to_s]
          end

          Array(signature_chunks).each do |piece|
            chunks << event_chunk(
              "content_block_delta",
              index: index,
              delta: {
                type: "signature_delta",
                signature: piece,
              },
            )
          end

          chunks << event_chunk("content_block_stop", index: index)
          chunks
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
