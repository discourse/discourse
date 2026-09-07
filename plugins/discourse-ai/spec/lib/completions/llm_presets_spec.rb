# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::LlmPresets do
  before { described_class.reset_cache! }
  after { described_class.reset_cache! }

  describe ".find_model" do
    it "carries adaptive thinking parameters through for current Anthropic reasoning models" do
      %w[claude-fable-5-1 claude-opus-5 claude-sonnet-5].each do |name|
        model = described_class.find_model("anthropic", name)

        expect(model[:provider_params]).to eq(enable_reasoning: true, adaptive_thinking: true),
        "expected #{name} preset to require adaptive thinking"
      end
    end

    it "omits provider parameters for models that do not need any" do
      model = described_class.find_model("anthropic", "claude-haiku-4-5-20251001")

      expect(model).not_to have_key(:provider_params)
    end

    it "uses the beta Gemini Interactions API for all Google models" do
      preset = described_class.find_provider("google")

      expect(preset).to include(
        provider: "gemini_interactions",
        endpoint: "https://generativelanguage.googleapis.com/v1beta/interactions",
      )
      expect(preset[:models].pluck(:name)).to eq(%w[gemini-3.1-pro-preview gemini-3.8-flash])
      expect(preset[:models]).to all(satisfy { |model| !model.key?(:endpoint) })
    end

    it "includes the current Google Vertex AI preset" do
      preset = described_class.find_provider("google_vertex_ai")
      model = preset[:models].first

      expect(preset[:provider]).to eq("google_vertex_ai")
      expect(preset[:tokenizer]).to eq(DiscourseAi::Tokenizer::GeminiTokenizer)
      expect(model).to include(
        name: "google/gemini-3.8-flash",
        display_name: "Gemini 3.8 Flash (Vertex)",
      )
      expect(model[:provider_params]).to include(region: "global")
    end

    it "includes the current GPT-5.6 family with pricing and capabilities" do
      preset = described_class.find_provider("open_ai")

      expect(preset[:models]).to eq(
        [
          {
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
          },
          {
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
          },
          {
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
          },
        ],
      )
    end

    it "includes the selected OpenRouter models and capabilities" do
      preset = described_class.find_provider("open_router")

      expect(preset[:models].pluck(:name)).to eq(
        %w[
          z-ai/glm-5.3-flash
          deepseek/deepseek-v4-flash-vision-exp
          tencent/hy4-preview
          xiaomi/mimo-v2.5
          moonshotai/kimi-k3
          minimax/minimax-m3
          x-ai/grok-4.6
        ],
      )
      expect(
        described_class.find_model("open_router", "deepseek/deepseek-v4-flash-vision-exp"),
      ).to include(vision_enabled: true)
    end
  end

  describe ".all" do
    it "has an English description for every model" do
      missing_keys =
        described_class.all.flat_map do |preset|
          preset[:models].filter_map do |model|
            key = "#{preset[:id]}-#{model[:name]}".gsub(%r{[./:]}, "-")
            key if !I18n.exists?("js.discourse_ai.llms.model_description.#{key}", :en)
          end
        end

      expect(missing_keys).to be_empty
    end
  end
end
