# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class OpenAiApiStyle < BaseStyle
        SUPPORTED_PROVIDERS = %w[open_ai azure groq open_router mistral samba_nova vllm]

        def self.can_handle?(llm_model)
          SUPPORTED_PROVIDERS.include?(llm_model.provider)
        end

        private

        def build_response(request)
          @response_id = nil
          super(request)
        end

        def streaming_request?(_request, payload)
          !!payload[:stream]
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

        def render_standard_message(response, payload)
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

        def render_standard_tool_calls(response, payload)
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

        def render_streaming_message(response, payload)
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

        def render_streaming_tool_calls(response, payload)
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
