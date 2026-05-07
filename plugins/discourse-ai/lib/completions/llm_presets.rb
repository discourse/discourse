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
                name: "claude-opus-4-7",
                tokens: 1_000_000,
                display_name: "Claude Opus 4.7",
                max_output_tokens: 128_000,
                input_cost: 5.0,
                cached_input_cost: 0.50,
                cache_write_cost: 6.25,
                output_cost: 25.0,
                vision_enabled: true,
              ),
              model(
                name: "claude-sonnet-4-6",
                tokens: 1_000_000,
                display_name: "Claude Sonnet 4.6",
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
                name: "gemini-3.1-pro",
                tokens: 1_000_000,
                display_name: "Gemini 3.1 Pro",
                max_output_tokens: 65_000,
                input_cost: 2.0,
                cached_input_cost: 0.20,
                output_cost: 12.0,
                vision_enabled: true,
                endpoint:
                  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-pro-preview",
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
                name: "gpt-5.5",
                tokens: 1_050_000,
                display_name: "GPT-5.5",
                max_output_tokens: 128_000,
                input_cost: 5.0,
                cached_input_cost: 0.50,
                output_cost: 30.0,
                vision_enabled: true,
                endpoint: "https://api.openai.com/v1/responses",
              ),
              model(
                name: "gpt-5.4",
                tokens: 400_000,
                display_name: "GPT-5.4",
                max_output_tokens: 128_000,
                input_cost: 2.50,
                cached_input_cost: 0.25,
                output_cost: 15.0,
                vision_enabled: true,
                endpoint: "https://api.openai.com/v1/responses",
              ),
              model(
                name: "gpt-5.4-nano",
                tokens: 400_000,
                display_name: "GPT-5.4 Nano",
                max_output_tokens: 128_000,
                input_cost: 0.20,
                cached_input_cost: 0.02,
                output_cost: 1.25,
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
                name: "moonshotai/kimi-k2.6",
                tokens: 262_144,
                display_name: "Moonshot Kimi K2.6",
                max_output_tokens: 131_072,
                input_cost: 0.74,
                cached_input_cost: 0.14,
                output_cost: 3.49,
                vision_enabled: true,
              ),
              model(
                name: "deepseek/deepseek-v4-flash",
                tokens: 1_048_576,
                display_name: "DeepSeek V4 Flash",
                max_output_tokens: 192_000,
                input_cost: 0.14,
                cached_input_cost: 0.0028,
                output_cost: 0.28,
              ),
              model(
                name: "minimax/minimax-m2.7",
                tokens: 196_608,
                display_name: "MiniMax M2.7",
                max_output_tokens: 65_536,
                input_cost: 0.30,
                cached_input_cost: 0.06,
                output_cost: 1.20,
              ),
              model(
                name: "x-ai/grok-4.1-fast",
                tokens: 2_000_000,
                display_name: "xAI Grok 4.1 Fast",
                max_output_tokens: 30_000,
                input_cost: 0.20,
                cached_input_cost: 0.05,
                output_cost: 0.50,
                vision_enabled: true,
              ),
              model(
                name: "z-ai/glm-5.1",
                tokens: 202_752,
                display_name: "Z-AI GLM-5.1",
                max_output_tokens: 65_536,
                input_cost: 1.05,
                cached_input_cost: 0.525,
                output_cost: 3.50,
              ),
              model(
                name: "qwen/qwen3.6-plus",
                tokens: 1_000_000,
                display_name: "Qwen3.6 Plus",
                max_output_tokens: 65_536,
                input_cost: 0.325,
                output_cost: 1.95,
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
