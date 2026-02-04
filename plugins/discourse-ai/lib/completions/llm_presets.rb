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
          [anthropic_preset, google_preset, open_ai_preset, open_router_preset].freeze
        end

        def anthropic_preset
          {
            id: "anthropic",
            models: [
              model(
                name: "claude-opus-4-5",
                tokens: 200_000,
                display_name: "Claude Opus 4.5",
                max_output_tokens: 64_000,
                input_cost: 5.0,
                cached_input_cost: 0.50,
                cache_write_cost: 6.25,
                output_cost: 25.0,
                vision_enabled: true,
              ),
              model(
                name: "claude-sonnet-4-5",
                tokens: 200_000,
                display_name: "Claude Sonnet 4.5",
                max_output_tokens: 64_000,
                input_cost: 3.0,
                cached_input_cost: 0.30,
                cache_write_cost: 3.75,
                output_cost: 15.0,
                vision_enabled: true,
              ),
              model(
                name: "claude-haiku-4-5",
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
                name: "gemini-3-pro",
                tokens: 1_000_000,
                display_name: "Gemini 3 Pro",
                max_output_tokens: 65_000,
                input_cost: 2.0,
                cached_input_cost: 0.20,
                output_cost: 12.0,
                vision_enabled: true,
                endpoint:
                  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-preview",
              ),
              model(
                name: "gemini-3-flash",
                tokens: 1_000_000,
                display_name: "Gemini 3 Flash",
                max_output_tokens: 65_000,
                input_cost: 0.50,
                cached_input_cost: 0.05,
                output_cost: 3.0,
                vision_enabled: true,
                endpoint:
                  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview",
              ),
            ],
            tokenizer: DiscourseAi::Tokenizer::GeminiTokenizer,
            provider: "google",
          }
        end

        def open_ai_preset
          {
            id: "open_ai",
            models: [
              model(
                name: "gpt-5.2",
                tokens: 400_000,
                display_name: "GPT-5.2",
                max_output_tokens: 128_000,
                input_cost: 1.25,
                cached_input_cost: 0.125,
                output_cost: 10.0,
                vision_enabled: true,
                endpoint: "https://api.openai.com/v1/responses",
              ),
              model(
                name: "gpt-5-mini",
                tokens: 400_000,
                display_name: "GPT-5 Mini",
                max_output_tokens: 128_000,
                input_cost: 0.25,
                cached_input_cost: 0.025,
                output_cost: 2.0,
                endpoint: "https://api.openai.com/v1/responses",
              ),
              model(
                name: "gpt-5-nano",
                tokens: 400_000,
                display_name: "GPT-5 Nano",
                max_output_tokens: 128_000,
                input_cost: 0.05,
                cached_input_cost: 0.005,
                output_cost: 0.40,
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
                name: "deepseek/deepseek-v3.2",
                tokens: 163_000,
                display_name: "DeepSeek V3.2",
                max_output_tokens: 32_000,
                input_cost: 0.27,
                output_cost: 1.10,
              ),
              model(
                name: "moonshotai/kimi-k2.5",
                tokens: 128_000,
                display_name: "Moonshot Kimi K2.5",
                max_output_tokens: 32_000,
                input_cost: 0.50,
                output_cost: 2.0,
                vision_enabled: true,
              ),
              model(
                name: "x-ai/grok-4-fast",
                tokens: 131_000,
                display_name: "xAI Grok 4 Fast",
                max_output_tokens: 32_000,
                input_cost: 3.0,
                output_cost: 15.0,
                vision_enabled: true,
              ),
              model(
                name: "minimax/minimax-m2.1",
                tokens: 256_000,
                display_name: "MiniMax M2.1",
                max_output_tokens: 32_000,
                input_cost: 0.40,
                output_cost: 1.60,
                vision_enabled: true,
              ),
              model(
                name: "z-ai/glm-4.7",
                tokens: 128_000,
                display_name: "Z-AI GLM-4.7",
                max_output_tokens: 32_000,
                input_cost: 0.30,
                output_cost: 1.20,
                vision_enabled: true,
              ),
              model(
                name: "arcee-ai/trinity-large-preview:free",
                tokens: 128_000,
                display_name: "Arcee Trinity Large (Free)",
                max_output_tokens: 32_000,
                input_cost: 0.0,
                output_cost: 0.0,
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
          endpoint: nil
        )
          result = { name: name, tokens: tokens, display_name: display_name }
          result[:max_output_tokens] = max_output_tokens if max_output_tokens
          result[:input_cost] = input_cost if input_cost
          result[:cached_input_cost] = cached_input_cost if cached_input_cost
          result[:cache_write_cost] = cache_write_cost if cache_write_cost
          result[:output_cost] = output_cost if output_cost
          result[:vision_enabled] = vision_enabled if vision_enabled
          result[:endpoint] = endpoint if endpoint
          result
        end
      end
    end
  end
end
