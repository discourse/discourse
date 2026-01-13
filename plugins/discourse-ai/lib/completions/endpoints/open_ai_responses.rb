# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class OpenAiResponses < Base
        def self.can_contact?(llm_model)
          %w[open_ai azure].include?(llm_model.provider) &&
            llm_model.url.to_s.include?("/v1/responses")
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup

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
          @native_tool_support = dialect.native_tool_support?
          super
        end

        private

        def disable_streaming?
          @disable_streaming ||= llm_model.lookup_custom_param("disable_streaming")
        end

        def reasoning_effort
          return @reasoning_effort if defined?(@reasoning_effort)
          @reasoning_effort = llm_model.lookup_custom_param("reasoning_effort")
          @reasoning_effort = nil if !%w[minimal low medium high].include?(@reasoning_effort)
          @reasoning_effort
        end

        def model_uri
          if llm_model.url.to_s.starts_with?("srv://")
            service = DiscourseAi::Utils::DnsSrv.lookup(llm_model.url.sub("srv://", ""))
            api_endpoint = "https://#{service.target}:#{service.port}/v1/responses"
          else
            api_endpoint = llm_model.url
          end

          @uri ||= URI(api_endpoint)
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = default_options.merge(model_params).merge(messages: prompt)

          reasoning_payload = { summary: "auto" }
          reasoning_payload[:effort] = reasoning_effort if reasoning_effort
          payload.merge!(reasoning: reasoning_payload)

          if @streaming_mode
            payload[:stream] = true
            payload[:stream_options] = { include_usage: true } if llm_model.provider == "open_ai"
          end

          if !xml_tools_enabled?
            if dialect.tools.present?
              payload[:tools] = dialect.tools
              if dialect.tool_choice.present?
                if dialect.tool_choice == :none
                  payload[:tool_choice] = "none"
                else
                  payload[:tool_choice] = { type: "function", name: dialect.tool_choice }
                end
              end
            end
          end

          convert_payload_to_responses_api!(payload)
          payload[:include] ||= []
          payload[:include] << "reasoning.encrypted_content"

          payload
        end

        def convert_payload_to_responses_api!(payload)
          payload[:input] = payload.delete(:messages)
          completion_tokens = payload.delete(:max_completion_tokens) || payload.delete(:max_tokens)
          payload[:max_output_tokens] = completion_tokens if completion_tokens

          if payload[:response_format]
            format = payload.delete(:response_format)
            if format && format[:json_schema]
              payload[:text] ||= {}
              payload[:text][:format] = format[:json_schema]
              payload[:text][:format][:type] ||= "json_schema"
            end
          end

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
          log.cache_read_tokens = processor.cache_read_tokens if processor.cache_read_tokens
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

          seen_tools = Set.new
          elements.select { |item| !item.is_a?(ToolCall) || seen_tools.add?(item) }
        end

        def decode_chunk_finish
          processor.finish
        end

        def xml_tools_enabled?
          !@native_tool_support
        end

        def processor
          @processor ||=
            OpenAiResponsesMessageProcessor.new(
              partial_tool_calls: partial_tool_calls,
              output_thinking: output_thinking,
            )
        end
      end
    end
  end
end
