# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class OpenRouter < OpenAi
        OPEN_ROUTER_REASONING_EFFORTS = %w[none minimal low medium high xhigh max].freeze

        def self.can_contact?(llm_model)
          llm_model.provider == "open_router"
        end

        def resolve_thinking_config(model_params)
          effort =
            DiscourseAi::Completions::ThinkingConfig.normalize_effort(
              model_params[:thinking_effort],
            )
          effort ||= legacy_reasoning_effort

          return DiscourseAi::Completions::ThinkingConfig.disabled if effort.blank?

          if !OPEN_ROUTER_REASONING_EFFORTS.include?(effort)
            return DiscourseAi::Completions::ThinkingConfig.unsupported(canonical_effort: effort)
          end

          DiscourseAi::Completions::ThinkingConfig.new(
            canonical_effort: effort,
            provider_effort: effort,
            enabled: effort != "none",
            explicit_none: effort == "none",
          )
        end

        def normalize_model_params(model_params)
          model_params = model_params.dup

          # max_tokens, temperature are already supported
          if model_params[:stop_sequences]
            model_params[:stop] = model_params.delete(:stop_sequences)
          end

          model_params.delete(:top_p) if llm_model.lookup_custom_param("disable_top_p")
          model_params.delete(:temperature) if llm_model.lookup_custom_param("disable_temperature")

          model_params
        end

        def prepare_request(payload)
          headers = { "Content-Type" => "application/json" }
          api_key = llm_model.api_key

          headers["Authorization"] = "Bearer #{api_key}"
          headers["X-Title"] = "Discourse AI"
          headers["HTTP-Referer"] = "https://www.discourse.org/ai"

          Net::HTTP::Post.new(model_uri, headers).tap { |r| r.body = payload }
        end

        def prepare_payload(prompt, model_params, dialect)
          payload = super
          payload.delete(:reasoning_effort)
          payload[:reasoning] = { effort: thinking_config.provider_effort } if thinking_configured?

          if quantizations = llm_model.provider_params["provider_quantizations"].presence
            options = quantizations.split(",").map(&:strip)

            payload[:provider] = { quantizations: options }
          end

          if order = llm_model.provider_params["provider_order"].presence
            options = order.split(",").map(&:strip)
            payload[:provider] ||= {}
            payload[:provider][:order] = options
          end

          payload
        end

        private

        def legacy_reasoning_effort
          effort = llm_model.lookup_custom_param("reasoning_effort")
          effort if OPEN_ROUTER_REASONING_EFFORTS.include?(effort)
        end
      end
    end
  end
end
