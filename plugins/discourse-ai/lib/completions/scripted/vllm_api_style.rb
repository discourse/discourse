# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      # vLLM streams OpenAI-shaped chunks but adds usage metrics to every event and expects
      # the initial assistant delta. We keep a dedicated style so specs can reproduce that
      # behaviour without bleeding it into other OpenAI-compatible providers.
      class VllmApiStyle < OpenAiApiStyle
        def self.can_handle?(llm_model)
          llm_model.provider == "vllm"
        end

        private

        def render_streaming_message(response, payload)
          content = response[:content].to_s
          usage = response[:usage] || usage_for_length(content.length, content, payload)
          model = payload[:model] || llm_model.name

          content_chunks = stream_chunks_for(content)
          chunks = []

          chunks << vllm_chunk(model, delta: { role: "assistant", content: "" }, usage: usage)

          content_chunks.each do |piece|
            chunks << vllm_chunk(model, delta: { content: piece }, usage: usage)
          end

          chunks << vllm_chunk(model, delta: {}, finish_reason: "stop", usage: usage)

          Response.new(chunks: chunks)
        end

        def vllm_chunk(model, delta:, finish_reason: nil, usage:)
          choice = { index: 0, delta: delta }
          choice[:finish_reason] = finish_reason if finish_reason

          payload = {
            id: response_id,
            object: "chat.completion.chunk",
            created: Time.now.to_i,
            model: model,
            choices: [choice],
            usage: usage,
          }

          "data: #{payload.to_json}\n\n"
        end
      end
    end
  end
end
