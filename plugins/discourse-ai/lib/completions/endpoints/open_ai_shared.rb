# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      module OpenAiShared
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
          execution_context: nil,
          &blk
        )
          @native_tool_support = dialect.native_tool_support?
          super
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup

          if model_params[:stop_sequences]
            model_params[:stop] = model_params.delete(:stop_sequences)
          end

          if reasoning_effort
            model_params.delete(:temperature)
            model_params.delete(:top_p)
          else
            model_params.delete(:top_p) if llm_model.lookup_custom_param("disable_top_p")
            if llm_model.lookup_custom_param("disable_temperature")
              model_params.delete(:temperature)
            end
          end

          model_params
        end

        private

        def disable_streaming?
          @disable_streaming ||= llm_model.lookup_custom_param("disable_streaming")
        end

        def reasoning_effort
          return @reasoning_effort if defined?(@reasoning_effort)
          @reasoning_effort = llm_model.lookup_custom_param("reasoning_effort")
          @reasoning_effort = nil if !%w[none minimal low medium high xhigh].include?(
            @reasoning_effort,
          )
          @reasoning_effort
        end

        def service_tier
          return @service_tier if defined?(@service_tier)
          @service_tier = llm_model.lookup_custom_param("service_tier")
          @service_tier = nil if !%w[auto flex priority].include?(@service_tier)
          @service_tier
        end

        def model_uri
          if llm_model.url.to_s.starts_with?("srv://")
            service = DiscourseAi::Utils::DnsSrv.lookup(llm_model.url.sub("srv://", ""))
            api_endpoint = "https://#{service.target}:#{service.port}#{srv_fallback_path}"
          else
            api_endpoint = llm_model.url
          end

          @uri ||= URI(api_endpoint)
        end

        def srv_fallback_path
          raise NotImplementedError
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

          # Remove duplicate partial tool calls
          # sometimes we stream weird chunks
          seen_tools = Set.new
          elements.select { |item| !item.is_a?(ToolCall) || seen_tools.add?(item) }
        end

        def decode_chunk_finish
          processor.finish
        end

        def xml_tools_enabled?
          !@native_tool_support
        end
      end
    end
  end
end
