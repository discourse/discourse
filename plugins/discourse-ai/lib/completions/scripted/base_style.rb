# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class BaseStyle
        def self.can_handle?(_llm_config)
          raise NotImplementedError
        end

        def initialize(raw_responses, llm_model)
          @raw_responses = raw_responses
          @llm_model = llm_model
          @last_request = nil
        end

        def request(request)
          @last_request = request
          response = build_response(request)

          if block_given?
            yield response
          else
            response
          end
        end

        def finish
          # Cleanup test-specific data.
          @last_request = nil
          # no-op; parity with Net::HTTP interface
        end

        attr_reader :last_request

        private

        attr_reader :raw_responses, :llm_model

        def build_response(request)
          payload = parse_payload(request.body)
          normalized = next_normalized_response

          streaming = streaming_request?(request, payload)

          if normalized[:type] == :raw_stream
            return render_raw_stream(normalized, streaming: streaming)
          end

          if streaming
            render_streaming_response(normalized, payload)
          else
            render_standard_response(normalized, payload)
          end
        end

        def parse_payload(body)
          JSON.parse(body, symbolize_names: true)
        rescue JSON::ParserError
          {}
        end

        def streaming_request?(_request, _payload)
          raise NotImplementedError
        end

        def next_normalized_response
          raise ArgumentError, "No scripted responses remaining" if raw_responses.empty?

          response = raw_responses.shift

          case response
          when String
            { type: :message, content: response }
          when Hash
            normalize_hash_response(response.deep_symbolize_keys)
          else
            raise ArgumentError,
                  "Unsupported scripted response #{response.class}. Use strings or hashes with :tool_call."
          end
        end

        def normalize_hash_response(response)
          usage = response[:usage]

          if response[:raw_stream]
            normalized = { type: :raw_stream, raw_stream: Array.wrap(response[:raw_stream]) }
            normalized[:usage] = usage if usage
            return normalized
          end

          normalized =
            if response[:tool_call]
              { type: :tool_calls, tool_calls: [normalize_tool_call(response[:tool_call])] }
            elsif response[:tool_calls]
              tools = Array.wrap(response[:tool_calls])
              raise ArgumentError, "tool_calls array cannot be empty" if tools.blank?
              { type: :tool_calls, tool_calls: tools.map { |tool| normalize_tool_call(tool) } }
            elsif response.key?(:content)
              { type: :message, content: response[:content].to_s }
            else
              raise ArgumentError,
                    "Supported hash responses must include :content, :tool_call, or :tool_calls. Got: #{response.keys.inspect}"
            end

          normalized[:usage] = usage if usage
          normalized
        end

        def normalize_tool_call(_tool_hash)
          raise NotImplementedError
        end

        def render_standard_response(response, payload)
          case response[:type]
          when :message
            render_standard_message(response, payload)
          when :tool_calls
            render_standard_tool_calls(response, payload)
          else
            raise ArgumentError, "Unsupported response type #{response[:type]}"
          end
        end

        def render_streaming_response(response, payload)
          case response[:type]
          when :message
            render_streaming_message(response, payload)
          when :tool_calls
            render_streaming_tool_calls(response, payload)
          else
            raise ArgumentError, "Unsupported response type #{response[:type]}"
          end
        end

        def render_standard_message(_response, _payload)
          raise NotImplementedError
        end

        def render_standard_tool_calls(_response, _payload)
          raise NotImplementedError
        end

        def render_streaming_message(_response, _payload)
          raise NotImplementedError
        end

        def render_streaming_tool_calls(_response, _payload)
          raise NotImplementedError
        end

        def render_raw_stream(response, streaming:)
          data = Array.wrap(response[:raw_stream])
          if streaming
            Response.new(chunks: data)
          else
            Response.new(body: data.join)
          end
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
      end
    end
  end
end
