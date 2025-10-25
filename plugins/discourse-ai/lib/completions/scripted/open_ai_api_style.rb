# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class OpenAiApiStyle < BaseStyle
        def self.can_handle?(_llm_model)
          true
        end

        private

        def build_response(request)
          @response_id = nil

          payload =
            begin
              JSON.parse(request.body, symbolize_names: true)
            rescue JSON::ParserError
              {}
            end

          response = next_response

          if payload[:stream]
            stream_response(response, payload)
          else
            standard_response(response, payload)
          end
        end

        def next_response
          raise ArgumentError, "No scripted responses remaining" if raw_responses.empty?

          response = raw_responses.shift

          case response
          when String
            { type: :message, content: response }
          when Hash
            normalize_hash_response(response.deep_symbolize_keys!)
          else
            raise ArgumentError,
                  "Unsupported scripted response #{response.class}. Use strings or hashes with :tool_call."
          end
        end

        def normalize_hash_response(response)
          usage = response[:usage]

          if (raw_chunks = response[:raw_stream])
            normalized = { type: :raw_stream, raw_stream: Array.wrap(raw_chunks) }
            normalized[:usage] = usage if usage
            return normalized
          end

          if (tool = response[:tool_call])
            normalized = { type: :tool_calls, tool_calls: [normalize_tool_call(tool)] }
          elsif (tools = response[:tool_calls])
            raise ArgumentError, "tool_calls array cannot be empty" if tools.blank?
            normalized = tools.map { |tool_hash| normalize_tool_call(tool_hash) }
            normalized = { type: :tool_calls, tool_calls: normalized }
          else
            raise ArgumentError,
                  "Supported hash responses must include :tool_call or :tool_calls key. Got: #{response.keys.inspect}"
          end

          normalized[:usage] = usage if usage
          normalized
        end

        def normalize_tool_call(tool_hash)
          name = tool_hash[:name]
          raise ArgumentError, "tool_call hash must include :name" if name.blank?

          id = tool_hash[:id] || "tool_#{SecureRandom.hex(8)}"

          raw_arguments = tool_hash[:arguments] || {}

          arguments =
            if raw_arguments.is_a?(String)
              raw_arguments
            else
              JSON.generate(raw_arguments, quirks_mode: true)
            end

          { id: id, name: name, arguments: arguments }
        end

        def standard_response(response, payload)
          case response[:type]
          when :message
            build_standard_message(response, payload)
          when :tool_calls
            build_standard_tool_calls(response, payload)
          when :raw_stream
            Response.new(body: Array.wrap(response[:raw_stream]).join)
          else
            raise ArgumentError, "Unknown scripted response type: #{response[:type]}"
          end
        end

        def stream_response(response, payload)
          case response[:type]
          when :message
            build_streaming_message(response, payload)
          when :tool_calls
            build_streaming_tool_calls(response, payload)
          when :raw_stream
            Response.new(chunks: Array.wrap(response[:raw_stream]))
          else
            raise ArgumentError, "Unknown scripted response type: #{response[:type]}"
          end
        end

        def build_standard_message(response, payload)
          content = response[:content]
          usage = response[:usage] || usage_for_length(content.length, content, payload)
          response_body = {
            id: response_id,
            object: "chat.completion",
            choices: [
              { index: 0, finish_reason: "stop", message: { role: "assistant", content: content } },
            ],
            usage: usage,
          }

          Response.new(body: response_body.to_json)
        end

        def build_standard_tool_calls(response, payload)
          tool_calls = response[:tool_calls]
          formatted =
            tool_calls.map do |tool|
              {
                id: tool[:id],
                type: "function",
                function: {
                  name: tool[:name],
                  arguments: tool[:arguments],
                },
              }
            end

          total_length = tool_calls.sum { |tool| tool[:arguments].length }
          usage = response[:usage] || usage_for_length(total_length, tool_calls.to_s, payload)

          response_body = {
            id: response_id,
            object: "chat.completion",
            choices: [
              {
                index: 0,
                finish_reason: "tool_calls",
                message: {
                  role: "assistant",
                  content: nil,
                  tool_calls: formatted,
                },
              },
            ],
            usage: usage,
          }

          Response.new(body: response_body.to_json)
        end

        def build_streaming_message(response, payload)
          content = response[:content]
          model = payload[:model] || "scripted-model"
          chunks = []

          chunks << sse_chunk(model, delta: { role: "assistant", content: "" })

          stream_chunks_for(content).each do |piece|
            chunks << sse_chunk(model, delta: { content: piece })
          end
          usage = response[:usage] || usage_for_length(content.length, content, payload)

          chunks << sse_chunk(model, delta: {}, finish_reason: "stop", usage: usage)

          Response.new(chunks: chunks)
        end

        def build_streaming_tool_calls(response, payload)
          tool_calls = response[:tool_calls]
          model = payload[:model] || "scripted-model"
          chunks = []

          tool_calls.each_with_index do |tool, index|
            header_delta = {
              tool_calls: [
                { index: index, id: tool[:id], function: { name: tool[:name], arguments: "" } },
              ],
            }

            chunks << sse_chunk(model, delta: header_delta)

            stream_chunks_for(tool[:arguments]).each do |piece|
              chunks << sse_chunk(
                model,
                delta: {
                  tool_calls: [{ index: index, function: { arguments: piece } }],
                },
              )
            end
          end

          total_length = tool_calls.sum { |tool| tool[:arguments].length }
          usage = response[:usage] || usage_for_length(total_length, tool_calls.to_s, payload)

          chunks << sse_chunk(model, delta: {}, finish_reason: "tool_calls", usage: usage)

          Response.new(chunks: chunks)
        end

        def stream_chunks_for(content)
          content = content.to_s
          return [content] if content.length <= 1

          remaining = content.length
          offset = 0
          pieces = []
          random = Random.new(Zlib.crc32(content))

          while remaining.positive?
            max_chunk = [remaining, 6].min
            size = random.rand(1..max_chunk)

            if remaining == content.length && remaining > 1 && size == remaining
              size = [remaining - 1, 1].max
            end

            pieces << content[offset, size]
            offset += size
            remaining -= size
          end

          pieces
        end

        def sse_chunk(model, delta:, finish_reason: nil, usage: nil)
          choice = { index: 0, delta: delta }
          choice[:finish_reason] = finish_reason if finish_reason

          payload = {
            id: response_id,
            object: "chat.completion.chunk",
            created: Time.now.to_i,
            model: model,
            choices: [choice],
          }

          payload[:usage] = usage if usage

          "data: #{payload.to_json}\n\n"
        end

        def usage_for_length(length, content, _payload)
          {
            prompt_tokens: length,
            completion_tokens: llm_model.tokenizer_class.size(content),
            total_tokens: length,
          }
        end

        def response_id
          @response_id ||= "scripted-#{SecureRandom.hex(4)}"
        end
      end
    end
  end
end
