# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class OpenAi < Base
        def self.can_contact?(model_provider)
          %w[open_ai azure].include?(model_provider)
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup

          # max_tokens is deprecated however we still need to support it
          # on older OpenAI models and older Azure models, so we will only normalize
          # if our model name starts with o (to denote all the reasoning models)
          if llm_model.name.starts_with?("o")
            max_tokens = model_params.delete(:max_tokens)
            model_params[:max_completion_tokens] = max_tokens if max_tokens
          end

          # temperature is already supported
          if model_params[:stop_sequences]
            model_params[:stop] = model_params.delete(:stop_sequences)
          end

          model_params.delete(:top_p) if llm_model.lookup_custom_param("disable_top_p")
          model_params.delete(:temperature) if llm_model.lookup_custom_param("disable_temperature")

          model_params
        end

        def default_options
          { model: llm_model.name }
        end

        def provider_id
          AiApiAuditLog::Provider::OpenAI
        end

        def perform_completion!(
          dialect,
          user,
          model_params = {},
          feature_name: nil,
          feature_context: nil,
          partial_tool_calls: false,
          output_thinking: false,
          cancel_manager: nil,
          &blk
        )
          @disable_native_tools = dialect.disable_native_tools?
          super
        end

        private

        def disable_streaming?
          @disable_streaming ||= llm_model.lookup_custom_param("disable_streaming")
        end

        def reasoning_effort
          return @reasoning_effort if defined?(@reasoning_effort)
          @reasoning_effort = llm_model.lookup_custom_param("reasoning_effort")
          @reasoning_effort = nil if !%w[low medium high].include?(@reasoning_effort)
          @reasoning_effort
        end

        def model_uri
          if llm_model.url.to_s.starts_with?("srv://")
            service = DiscourseAi::Utils::DnsSrv.lookup(llm_model.url.sub("srv://", ""))
            api_endpoint = "https://#{service.target}:#{service.port}/v1/chat/completions"
          else
            api_endpoint = llm_model.url
          end

          @uri ||= URI(api_endpoint)
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = default_options.merge(model_params).merge(messages: prompt)

          payload[:reasoning_effort] = reasoning_effort if reasoning_effort

          if @streaming_mode
            payload[:stream] = true

            # Usage is not available in Azure yet.
            # We'll fallback to guess this using the tokenizer.
            payload[:stream_options] = { include_usage: true } if llm_model.provider == "open_ai"
          end

          if !xml_tools_enabled?
            if dialect.tools.present?
              payload[:tools] = dialect.tools
              if dialect.tool_choice.present?
                if dialect.tool_choice == :none
                  payload[:tool_choice] = "none"
                else
                  if responses_api?
                    payload[:tool_choice] = { type: "function", name: dialect.tool_choice }
                  else
                    payload[:tool_choice] = {
                      type: "function",
                      function: {
                        name: dialect.tool_choice,
                      },
                    }
                  end
                end
              end
            end
          end

          convert_payload_to_responses_api!(payload) if responses_api?

          payload
        end

        def responses_api?
          return @responses_api if defined?(@responses_api)
          @responses_api = llm_model.lookup_custom_param("enable_responses_api")
        end

        def convert_payload_to_responses_api!(payload)
          payload[:input] = payload.delete(:messages)
          completion_tokens = payload.delete(:max_completion_tokens) || payload.delete(:max_tokens)
          payload[:max_output_tokens] = completion_tokens if completion_tokens
          # not supported in responses api
          payload.delete(:stream_options)
        end

        def prepare_request(payload)
          headers = { "Content-Type" => "application/json" }
          api_key = llm_model.api_key

          if llm_model.provider == "azure"
            headers["api-key"] = api_key
          else
            headers["Authorization"] = "Bearer #{api_key}"
            org_id = llm_model.lookup_custom_param("organization")
            headers["OpenAI-Organization"] = org_id if org_id.present?
          end

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def final_log_update(log)
          log.request_tokens = processor.prompt_tokens if processor.prompt_tokens
          log.response_tokens = processor.completion_tokens if processor.completion_tokens
          log.cached_tokens = processor.cached_tokens if processor.cached_tokens
        end

        def decode(response_raw)
          processor.process_message(JSON.parse(response_raw, symbolize_names: true))
        end

        def decode_chunk(chunk)
          @decoder ||= JsonStreamDecoder.new
          elements =
            (@decoder << chunk)
              .map { |parsed_json| processor.process_streamed_message(parsed_json) }
              .flatten
              .compact

          # Remove duplicate partial tool calls
          # sometimes we stream weird chunks
          seen_tools = Set.new
          elements.select { |item| !item.is_a?(ToolCall) || seen_tools.add?(item) }
        end

        def decode_chunk_finish
          processor.finish
        end

        def xml_tools_enabled?
          !!@disable_native_tools
        end

        private

        def processor
          @processor ||=
            if responses_api?
              OpenAiResponsesMessageProcessor.new(partial_tool_calls: partial_tool_calls)
            else
              OpenAiMessageProcessor.new(partial_tool_calls: partial_tool_calls)
            end
        end
      end
    end
  end
end
