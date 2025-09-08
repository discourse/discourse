# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class HuggingFace < Base
        def self.can_contact?(model_provider)
          model_provider == "hugging_face"
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
          { model: llm_model.name, temperature: 0.7 }
        end

        def provider_id
          AiApiAuditLog::Provider::HuggingFaceTextGeneration
        end

        private

        def model_uri
          URI(llm_model.url)
        end

        def prepare_payload(prompt, model_params, _dialect)
          default_options
            .merge(model_params)
            .merge(messages: prompt)
            .tap do |payload|
              if !payload[:max_tokens]
                token_limit = llm_model.max_prompt_tokens

                payload[:max_tokens] = token_limit - prompt_size(prompt)
              end

              payload[:stream] = true if @streaming_mode
            end
        end

        def prepare_request(payload)
          api_key = llm_model.api_key

          headers =
            { "Content-Type" => "application/json" }.tap do |h|
              h["Authorization"] = "Bearer #{api_key}" if api_key.present?
            end

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def xml_tools_enabled?
          true
        end

        def decode(response_raw)
          parsed = JSON.parse(response_raw, symbolize_names: true)
          text = parsed.dig(:choices, 0, :message, :content)
          if text.to_s.empty?
            [""]
          else
            [text]
          end
        end

        def decode_chunk(chunk)
          @json_decoder ||= JsonStreamDecoder.new
          (@json_decoder << chunk)
            .map do |parsed|
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
