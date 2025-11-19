# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Scripted
      class OpenAiResponsesApiStyle < BaseStyle
        SUPPORTED_PROVIDERS = %w[open_ai azure groq].freeze

        def self.can_handle?(llm_model)
          llm_model.lookup_custom_param("enable_responses_api") &&
            SUPPORTED_PROVIDERS.include?(llm_model.provider)
        end

        private

        def normalize_hash_response(response)
          normalized = super

          if response[:text_chunks]
            normalized[:text_chunks] = Array.wrap(response[:text_chunks]).map(&:to_s)
          end

          if response[:reasoning]
            reasoning = response[:reasoning].deep_symbolize_keys
            normalized[:reasoning] = {
              id: reasoning[:id] || "rs_#{SecureRandom.hex(8)}",
              encrypted_content: reasoning[:encrypted_content],
              deltas: Array.wrap(reasoning[:deltas]).map(&:to_s),
              summary: reasoning[:summary],
            }
          end

          normalized[:message_id] = response[:message_id].to_s if response[:message_id]

          normalized
        end

        def streaming_request?(_request, payload)
          !!payload[:stream]
        end

        def normalize_tool_call(tool_hash)
          name = tool_hash[:name]
          raise ArgumentError, "tool_call hash must include :name" if name.blank?

          id = tool_hash[:id] || "call_#{SecureRandom.hex(8)}"
          arguments = normalize_arguments(tool_hash[:arguments])

          { id: id, name: name, arguments: arguments }
        end

        def render_standard_message(response, payload)
          content = response[:content]
          usage = normalize_usage(response[:usage], content, payload)

          body = response_payload(payload, usage: usage, output: [message_item(content)])

          Response.new(body: body.to_json)
        end

        def render_standard_tool_calls(response, payload)
          tool_calls = response[:tool_calls]
          usage = normalize_usage(response[:usage], tool_calls_to_text(tool_calls), payload)

          output =
            tool_calls.map do |tool|
              {
                id: tool[:id],
                type: "function_call",
                status: "completed",
                arguments: tool[:arguments],
                call_id: tool[:id],
                name: tool[:name],
              }
            end

          body = response_payload(payload, usage: usage, output: output)

          Response.new(body: body.to_json)
        end

        def render_streaming_message(response, payload)
          content = response[:content]
          usage = normalize_usage(response[:usage], content, payload)
          model = payload[:model] || "scripted-model"
          item_id = response[:message_id] || "msg_#{SecureRandom.hex(8)}"
          sequence = 0
          text_chunks = response[:text_chunks] || stream_chunks_for(content)
          final_content = text_chunks.join

          chunks = []

          chunks << event_chunk(
            "response.created",
            sequence: sequence += 1,
            response: in_progress_response(model),
          )
          chunks << event_chunk(
            "response.in_progress",
            sequence: sequence += 1,
            response: in_progress_response(model),
          )

          output_index = 0
          reasoning_item = nil

          if response[:reasoning]
            reasoning_item, sequence_updates =
              render_reasoning_stream(response[:reasoning], sequence, output_index: 0)
            sequence = sequence_updates[:sequence]
            chunks.concat(sequence_updates[:chunks])
            output_index += 1
          end

          chunks << event_chunk(
            "response.output_item.added",
            sequence: sequence += 1,
            output_index: output_index,
            item: {
              id: item_id,
              type: "message",
              status: "in_progress",
              content: [],
              role: "assistant",
            },
          )
          chunks << event_chunk(
            "response.content_part.added",
            sequence: sequence += 1,
            item_id: item_id,
            output_index: output_index,
            content_index: 0,
            part: {
              type: "output_text",
              annotations: [],
              text: "",
            },
          )

          text_chunks.each do |piece|
            chunks << event_chunk(
              "response.output_text.delta",
              sequence: sequence += 1,
              item_id: item_id,
              output_index: output_index,
              content_index: 0,
              delta: piece,
            )
          end

          chunks << event_chunk(
            "response.output_text.done",
            sequence: sequence += 1,
            item_id: item_id,
            output_index: output_index,
            content_index: 0,
            text: final_content,
          )

          chunks << event_chunk(
            "response.output_item.done",
            sequence: sequence += 1,
            output_index: output_index,
            item: message_item(final_content, id: item_id),
          )

          final_output = []
          final_output << reasoning_item if reasoning_item
          final_output << message_item(final_content, id: item_id)

          chunks << event_chunk(
            "response.completed",
            sequence: sequence + 1,
            response:
              response_payload(payload, usage: usage, output: final_output, status: "completed"),
          )

          Response.new(chunks: chunks)
        end

        def render_streaming_tool_calls(response, payload)
          tool_calls = response[:tool_calls]
          usage = normalize_usage(response[:usage], tool_calls_to_text(tool_calls), payload)
          model = payload[:model] || "scripted-model"
          sequence = 0
          chunks = []

          chunks << event_chunk(
            "response.created",
            sequence: sequence += 1,
            response: in_progress_response(model),
          )
          chunks << event_chunk(
            "response.in_progress",
            sequence: sequence += 1,
            response: in_progress_response(model),
          )

          tool_calls.each_with_index do |tool, index|
            chunks << event_chunk(
              "response.output_item.added",
              sequence: sequence += 1,
              output_index: index,
              item: {
                id: tool[:id],
                type: "function_call",
                status: "in_progress",
                arguments: "",
                call_id: tool[:id],
                name: tool[:name],
              },
            )

            stream_chunks_for(tool[:arguments]).each do |piece|
              chunks << event_chunk(
                "response.function_call_arguments.delta",
                sequence: sequence += 1,
                item_id: tool[:id],
                output_index: index,
                delta: piece,
              )
            end

            chunks << event_chunk(
              "response.function_call_arguments.done",
              sequence: sequence += 1,
              item_id: tool[:id],
              output_index: index,
              arguments: tool[:arguments],
            )

            chunks << event_chunk(
              "response.output_item.done",
              sequence: sequence += 1,
              output_index: index,
              item: {
                id: tool[:id],
                type: "function_call",
                status: "completed",
                arguments: tool[:arguments],
                call_id: tool[:id],
                name: tool[:name],
              },
            )
          end

          chunks << event_chunk(
            "response.completed",
            sequence: sequence + 1,
            response:
              response_payload(
                payload,
                usage: usage,
                output: formatted_tool_output(tool_calls),
                status: "completed",
              ),
          )

          Response.new(chunks: chunks)
        end

        def response_payload(payload, usage:, output:, status: "completed")
          {
            id: response_id,
            object: "response",
            created_at: Time.now.to_i,
            status: status,
            model: payload[:model] || "scripted-model",
            output: output,
            parallel_tool_calls: true,
            usage: usage,
            text: {
              format: {
                type: "text",
              },
            },
            tool_choice: "auto",
            tools: [],
            top_p: 1.0,
            truncation: "disabled",
          }
        end

        def formatted_tool_output(tool_calls)
          tool_calls.map do |tool|
            {
              id: tool[:id],
              type: "function_call",
              status: "completed",
              arguments: tool[:arguments],
              call_id: tool[:id],
              name: tool[:name],
            }
          end
        end

        def in_progress_response(model)
          {
            id: response_id,
            object: "response",
            created_at: Time.now.to_i,
            status: "in_progress",
            model: model,
            output: [],
            parallel_tool_calls: true,
            text: {
              format: {
                type: "text",
              },
            },
            tools: [],
            tool_choice: "auto",
            usage: nil,
          }
        end

        def normalize_usage(raw_usage, content, payload)
          usage = raw_usage&.deep_symbolize_keys
          if usage
            input_tokens = usage[:input_tokens] || usage[:prompt_tokens] || 0
            output_tokens = usage[:output_tokens] || usage[:completion_tokens] || 0
            cached_tokens =
              usage.dig(:input_tokens_details, :cached_tokens) || usage[:cached_tokens] ||
                usage.dig(:prompt_tokens_details, :cached_tokens) || 0

            return(
              {
                input_tokens: input_tokens,
                input_tokens_details: {
                  cached_tokens: cached_tokens,
                },
                output_tokens: output_tokens,
                output_tokens_details: {
                  reasoning_tokens: 0,
                },
                total_tokens: usage[:total_tokens] || input_tokens + output_tokens,
              }
            )
          end

          completion_tokens = llm_model.tokenizer_class.size(content.to_s)
          prompt_tokens = payload[:input].to_s.length + payload[:messages].to_s.length

          {
            input_tokens: prompt_tokens,
            input_tokens_details: {
              cached_tokens: 0,
            },
            output_tokens: completion_tokens,
            output_tokens_details: {
              reasoning_tokens: 0,
            },
            total_tokens: prompt_tokens + completion_tokens,
          }
        end

        def event_chunk(event_name, sequence:, **data)
          payload = data.merge(type: event_name, sequence_number: sequence)
          "data: #{payload.to_json}\n\n"
        end

        def render_reasoning_stream(reasoning, sequence, output_index:)
          reasoning_id = reasoning[:id]
          encrypted_content = reasoning[:encrypted_content]
          deltas = reasoning[:deltas] || []
          summary = reasoning[:summary] || deltas.join

          chunks = []

          chunks << event_chunk(
            "response.output_item.added",
            sequence: sequence += 1,
            output_index: output_index,
            item: {
              id: reasoning_id,
              type: "reasoning",
              encrypted_content: encrypted_content,
              summary: [],
            },
          )

          chunks << event_chunk(
            "response.reasoning_summary_part.added",
            sequence: sequence += 1,
            item_id: reasoning_id,
            output_index: output_index,
            summary_index: 0,
            part: {
              type: "summary_text",
              text: "",
            },
          )

          deltas.each do |delta|
            chunks << event_chunk(
              "response.reasoning_summary_text.delta",
              sequence: sequence += 1,
              item_id: reasoning_id,
              output_index: output_index,
              summary_index: 0,
              delta: delta,
            )
          end

          reasoning_item = {
            id: reasoning_id,
            type: "reasoning",
            encrypted_content: encrypted_content,
            summary: [{ type: "summary_text", text: summary }],
          }

          chunks << event_chunk(
            "response.output_item.done",
            sequence: sequence += 1,
            output_index: output_index,
            item: reasoning_item,
          )

          [reasoning_item, { sequence: sequence, chunks: chunks }]
        end

        def message_item(content, id: "msg_#{SecureRandom.hex(8)}")
          {
            id: id,
            type: "message",
            status: "completed",
            content: [{ type: "output_text", annotations: [], text: content }],
            role: "assistant",
          }
        end

        def normalize_arguments(raw_arguments)
          return "" if raw_arguments.nil?
          return raw_arguments if raw_arguments.is_a?(String)

          JSON.generate(raw_arguments, quirks_mode: true)
        end

        def tool_calls_to_text(tool_calls)
          tool_calls.map { |tool| tool[:arguments].to_s }.join("\n")
        end

        def response_id
          @response_id ||= "resp_#{SecureRandom.hex(8)}"
        end
      end
    end
  end
end
