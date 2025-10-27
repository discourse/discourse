# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class GeminiApiStyle < BaseStyle
        def self.can_handle?(llm_model)
          llm_model.provider == "google"
        end

        private

        def streaming_request?(request, _payload)
          request.path&.include?(":streamGenerateContent")
        end

        def normalize_tool_call(tool_hash)
          name = tool_hash[:name]
          raise ArgumentError, "tool_call hash must include :name" if name.blank?

          raw_arguments = tool_hash[:arguments]
          arguments =
            case raw_arguments
            when nil
              {}
            when String
              JSON.parse(raw_arguments, symbolize_names: true)
            when Hash
              raw_arguments.deep_symbolize_keys
            else
              raw_arguments
            end

          { name: name, arguments: arguments }
        end

        def render_standard_message(response, payload)
          content = response[:content].to_s
          usage = response[:usage] || usage_for_text(content, payload)

          Response.new(
            body: envelope(parts: [{ text: content }], finish_reason: "STOP", usage: usage).to_json,
          )
        end

        def render_standard_tool_calls(response, payload)
          tool_calls = response[:tool_calls]
          usage = response[:usage] || usage_for_tool_calls(tool_calls, payload)

          parts =
            tool_calls.map do |tool|
              { functionCall: { name: tool[:name], args: tool[:arguments] } }
            end

          Response.new(body: envelope(parts: parts, finish_reason: "STOP", usage: usage).to_json)
        end

        def render_streaming_message(response, payload)
          content = response[:content].to_s
          usage = response[:usage] || usage_for_text(content, payload)
          chunks = []

          stream_chunks_for(content).each do |piece|
            chunks << sse_chunk(envelope(parts: [{ text: piece }]))
          end

          chunks << sse_chunk(envelope(parts: [{ text: "" }], finish_reason: "STOP", usage: usage))

          Response.new(chunks: chunks)
        end

        def render_streaming_tool_calls(response, payload)
          tool_calls = response[:tool_calls]
          usage = response[:usage] || usage_for_tool_calls(tool_calls, payload)
          chunks = []

          tool_calls.each do |tool|
            parts = [{ functionCall: { name: tool[:name], args: tool[:arguments] } }]
            chunks << sse_chunk(envelope(parts: parts))
          end

          chunks << sse_chunk(envelope(parts: [{ text: "" }], finish_reason: "STOP", usage: usage))

          Response.new(chunks: chunks)
        end

        def usage_for_text(content, payload)
          candidate_tokens = llm_model.tokenizer_class.size(content.to_s)
          usage_metadata(payload, candidate_tokens)
        end

        def usage_for_tool_calls(tool_calls, payload)
          arguments_text =
            tool_calls.map { |tool| JSON.generate(tool[:arguments], quirks_mode: true) }.join
          candidate_tokens = llm_model.tokenizer_class.size(arguments_text)
          usage_metadata(payload, candidate_tokens)
        end

        def usage_metadata(payload, candidate_tokens)
          prompt_tokens = prompt_token_estimate(payload)
          {
            promptTokenCount: prompt_tokens,
            candidatesTokenCount: candidate_tokens,
            totalTokenCount: prompt_tokens + candidate_tokens,
          }
        end

        def prompt_token_estimate(payload)
          contents = Array(payload[:contents])
          combined =
            contents
              .flat_map { |content| Array(content[:parts]) }
              .map { |part| part[:text].to_s }
              .join

          llm_model.tokenizer_class.size(combined)
        end

        def envelope(parts:, finish_reason: nil, usage: nil)
          candidate = { content: { parts: parts, role: "model" }, index: 0 }
          candidate[:finishReason] = finish_reason if finish_reason

          response = { candidates: [candidate], modelVersion: llm_model.name }
          response[:usageMetadata] = usage if usage
          response
        end

        def sse_chunk(payload)
          "data: #{payload.to_json}\n\n"
        end
      end
    end
  end
end
