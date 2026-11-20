# frozen_string_literal: true

module DiscourseAi
  module Completions
    class LlmPresets
      class << self
        def all
          @all ||= build_presets
        end

        def find_provider(provider_id)
          all.find { |preset| preset[:id] == provider_id }
        end

        def find_model(provider_id, model_name)
          provider = find_provider(provider_id)
          return nil unless provider
          provider[:models].find { |m| m[:name] == model_name }
        end

        def reset_cache!
          @all = nil
        end

        private

        def build_presets
          [
            anthropic_preset,
            google_preset,
            google_vertex_ai_preset,
            open_ai_preset,
            open_router_preset,
          ].freeze
        end

        def anthropic_preset
          {
            id: "anthropic",
            models: [
              model(
                name: "claude-fable-5-1",
                tokens: 1_000_000,
                display_name: "Claude Fable 5.1",
                max_output_tokens: 128_000,
                input_cost: 10.0,
                cached_input_cost: 0.25,
                cache_write_cost: 12.50,
                output_cost: 50.0,
                vision_enabled: true,
                provider_params: {
                  enable_reasoning: true,
                  adaptive_thinking: true,
                },
              ),
              model(
                name: "claude-opus-5",
                tokens: 1_000_000,
                display_name: "Claude Opus 5",
                max_output_tokens: 128_000,
                input_cost: 5.0,
                cached_input_cost: 0.50,
                cache_write_cost: 6.25,
                output_cost: 25.0,
                vision_enabled: true,
                provider_params: {
                  enable_reasoning: true,
                  adaptive_thinking: true,
                },
              ),
              model(
                name: "claude-sonnet-5",
                tokens: 1_000_000,
                display_name: "Claude Sonnet 5",
                max_output_tokens: 128_000,
                input_cost: 2.0,
                cached_input_cost: 0.20,
                cache_write_cost: 2.50,
                output_cost: 10.0,
                vision_enabled: true,
                provider_params: {
                  enable_reasoning: true,
                  adaptive_thinking: true,
                },
              ),
              model(
                name: "claude-haiku-4-5-20251001",
                tokens: 200_000,
                display_name: "Claude Haiku 4.5",
                max_output_tokens: 64_000,
                input_cost: 1.0,
                cached_input_cost: 0.10,
                cache_write_cost: 1.25,
                output_cost: 5.0,
                vision_enabled: true,
              ),
            ],
            tokenizer: DiscourseAi::Tokenizer::AnthropicTokenizer,
            endpoint: "https://api.anthropic.com/v1/messages",
            provider: "anthropic",
          }
        end

        def google_preset
          {
            id: "google",
            models: [
              model(
                name: "gemini-3.1-pro-preview",
                tokens: 1_048_576,
                display_name: "Gemini 3.1 Pro Preview",
                max_output_tokens: 65_536,
                input_cost: 2.0,
                cached_input_cost: 0.20,
                output_cost: 12.0,
                vision_enabled: true,
              ),
              model(
                name: "gemini-3.8-flash",
                tokens: 1_048_576,
                display_name: "Gemini 3.8 Flash",
                max_output_tokens: 65_536,
                input_cost: 0.75,
                cached_input_cost: 0.075,
                output_cost: 3.75,
                vision_enabled: true,
              ),
            ],
            tokenizer: DiscourseAi::Tokenizer::GeminiTokenizer,
            endpoint: "https://generativelanguage.googleapis.com/v1beta/interactions",
            provider: "gemini_interactions",
          }
        end

        def google_vertex_ai_preset
          {
            id: "google_vertex_ai",
            models: [
              model(
                name: "google/gemini-3.8-flash",
                tokens: 1_048_576,
                display_name: "Gemini 3.8 Flash (Vertex)",
                max_output_tokens: 65_536,
                input_cost: 0.75,
                cached_input_cost: 0.075,
                output_cost: 3.75,
                vision_enabled: true,
                provider_params: {
                  region: "global",
                },
              ),
            ],
            tokenizer: DiscourseAi::Tokenizer::GeminiTokenizer,
            provider: "google_vertex_ai",
          }
        end

        def open_ai_preset
          {
            id: "open_ai",
            models: [
              model(
                name: "gpt-5.6-sol",
                tokens: 1_050_000,
                display_name: "GPT-5.6 Sol",
                max_output_tokens: 128_000,
                input_cost: 4.0,
                cached_input_cost: 0.40,
                cache_write_cost: 5.0,
                output_cost: 20.0,
                vision_enabled: true,
                endpoint: "https://api.openai.com/v1/responses",
              ),
              model(
                name: "gpt-5.6-terra",
                tokens: 1_050_000,
                display_name: "GPT-5.6 Terra",
                max_output_tokens: 128_000,
                input_cost: 2.0,
                cached_input_cost: 0.20,
                cache_write_cost: 2.50,
                output_cost: 12.0,
                vision_enabled: true,
                endpoint: "https://api.openai.com/v1/responses",
              ),
              model(
                name: "gpt-5.6-luna",
                tokens: 1_050_000,
                display_name: "GPT-5.6 Luna",
                max_output_tokens: 128_000,
                input_cost: 0.20,
                cached_input_cost: 0.02,
                cache_write_cost: 0.25,
                output_cost: 1.20,
                vision_enabled: true,
                endpoint: "https://api.openai.com/v1/responses",
              ),
            ],
            tokenizer: DiscourseAi::Tokenizer::OpenAiTokenizer,
            endpoint: "https://api.openai.com/v1/chat/completions",
            provider: "open_ai",
          }
        end

        def open_router_preset
          {
            id: "open_router",
            models: [
              model(
                name: "z-ai/glm-5.3-flash",
                tokens: 1_310_720,
                display_name: "Z.AI GLM 5.3 Flash",
                max_output_tokens: 131_072,
                input_cost: 0.075,
                cached_input_cost: 0.015,
                output_cost: 0.25,
                vision_enabled: true,
              ),
              model(
                name: "deepseek/deepseek-v4-flash-vision-exp",
                tokens: 1_048_576,
                display_name: "DeepSeek V4 Flash Vision Exp",
                max_output_tokens: 384_000,
                input_cost: 0.44,
                cached_input_cost: 0.014,
                output_cost: 1.32,
                vision_enabled: true,
              ),
              model(
                name: "tencent/hy4-preview",
                tokens: 1_048_576,
                display_name: "Tencent Hy4 Preview",
                max_output_tokens: 64_000,
                input_cost: 0.834,
                cached_input_cost: 0.042,
                output_cost: 2.501,
              ),
              model(
                name: "xiaomi/mimo-v2.5",
                tokens: 1_050_000,
                display_name: "Xiaomi MiMo-V2.5",
                max_output_tokens: 131_072,
                input_cost: 0.14,
                cached_input_cost: 0.0028,
                output_cost: 0.28,
                vision_enabled: true,
              ),
              model(
                name: "moonshotai/kimi-k3",
                tokens: 1_048_576,
                display_name: "Moonshot Kimi K3",
                max_output_tokens: 943_718,
                input_cost: 3.0,
                cached_input_cost: 0.30,
                output_cost: 15.0,
                vision_enabled: true,
              ),
              model(
                name: "minimax/minimax-m3",
                tokens: 1_048_576,
                display_name: "MiniMax M3",
                max_output_tokens: 512_000,
                input_cost: 0.30,
                cached_input_cost: 0.06,
                output_cost: 1.20,
                vision_enabled: true,
              ),
              model(
                name: "x-ai/grok-4.6",
                tokens: 500_000,
                display_name: "xAI Grok 4.6",
                max_output_tokens: 450_000,
                input_cost: 2.0,
                cached_input_cost: 0.50,
                output_cost: 6.0,
                vision_enabled: true,
              ),
            ],
            tokenizer: DiscourseAi::Tokenizer::OpenAiTokenizer,
            endpoint: "https://openrouter.ai/api/v1/chat/completions",
            provider: "open_router",
          }
        end

        def model(
          name:,
          tokens:,
          display_name:,
          max_output_tokens: nil,
          input_cost: nil,
          cached_input_cost: nil,
          cache_write_cost: nil,
          output_cost: nil,
          vision_enabled: false,
          endpoint: nil,
          provider_params: nil
        )
          result = { name: name, tokens: tokens, display_name: display_name }
          result[:max_output_tokens] = max_output_tokens if max_output_tokens
          result[:input_cost] = input_cost if input_cost
          result[:cached_input_cost] = cached_input_cost if cached_input_cost
          result[:cache_write_cost] = cache_write_cost if cache_write_cost
          result[:output_cost] = output_cost if output_cost
          result[:vision_enabled] = vision_enabled if vision_enabled
          result[:endpoint] = endpoint if endpoint
          result[:provider_params] = provider_params if provider_params
          result
        end
      end
    end
  end
end
