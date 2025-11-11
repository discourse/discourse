# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Vllm < Base
        def self.can_contact?(model_provider)
          model_provider == "vllm"
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup

          # max_tokens, temperature are already supported
          if model_params[:stop_sequences]
            model_params[:stop] = model_params.delete(:stop_sequences)
          end

          model_params
        end

        def default_options
          { max_tokens: 2000, model: llm_model.name }
        end

        def provider_id
          AiApiAuditLog::Provider::Vllm
        end

        private

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
          if @streaming_mode
            payload[:stream] = true if @streaming_mode
            payload[:stream_options] = { include_usage: true }
          end

          payload
        end

        def prepare_request(payload)
          headers = { "Referer" => Discourse.base_url, "Content-Type" => "application/json" }

          api_key = llm_model&.api_key || SiteSetting.ai_vllm_api_key
          headers["X-API-KEY"] = api_key if api_key.present?

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def xml_tools_enabled?
          true
        end

        def final_log_update(log)
          log.request_tokens = @prompt_tokens if @prompt_tokens
          log.response_tokens = @completion_tokens if @completion_tokens
        end

        def decode(response_raw)
          json = JSON.parse(response_raw, symbolize_names: true)
          @prompt_tokens = json.dig(:usage, :prompt_tokens)
          @completion_tokens = json.dig(:usage, :completion_tokens)
          [json.dig(:choices, 0, :message, :content)]
        end

        def decode_chunk(chunk)
          @json_decoder ||= JsonStreamDecoder.new
          (@json_decoder << chunk)
            .map do |parsed|
              # vLLM keeps sending usage over and over again
              prompt_tokens = parsed.dig(:usage, :prompt_tokens)
              completion_tokens = parsed.dig(:usage, :completion_tokens)

              @prompt_tokens = prompt_tokens if prompt_tokens

              @completion_tokens = completion_tokens if completion_tokens

              text = parsed.dig(:choices, 0, :delta, :content)
              if text.to_s.empty?
                nil
              else
                text
              end
            end
            .compact
        end
      end
    end
  end
end
