# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::LlmPresets do
  before { described_class.reset_cache! }
  after { described_class.reset_cache! }

  describe ".find_model" do
    it "carries provider_params through for models that need them, e.g. adaptive thinking" do
      model = described_class.find_model("anthropic", "claude-opus-4-7")

      expect(model[:provider_params]).to eq(enable_reasoning: true, adaptive_thinking: true)
    end

    it "omits provider_params for models that don't need any" do
      model = described_class.find_model("anthropic", "claude-sonnet-4-6")

      expect(model).not_to have_key(:provider_params)
    end

    it "includes a Google Vertex AI preset" do
      preset = described_class.find_provider("google_vertex_ai")
      model = preset[:models].first

      expect(preset[:provider]).to eq("google_vertex_ai")
      expect(preset[:tokenizer]).to eq(DiscourseAi::Tokenizer::GeminiTokenizer)
      expect(model).to include(
        name: "google/gemini-3-flash",
        display_name: "Gemini 3 Flash (Vertex)",
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
            input_cost: 5.0,
            cached_input_cost: 0.50,
            cache_write_cost: 6.25,
            output_cost: 30.0,
            vision_enabled: true,
            endpoint: "https://api.openai.com/v1/responses",
          },
          {
            name: "gpt-5.6-terra",
            tokens: 1_050_000,
            display_name: "GPT-5.6 Terra",
            max_output_tokens: 128_000,
            input_cost: 2.50,
            cached_input_cost: 0.25,
            cache_write_cost: 3.125,
            output_cost: 15.0,
            vision_enabled: true,
            endpoint: "https://api.openai.com/v1/responses",
          },
          {
            name: "gpt-5.6-luna",
            tokens: 1_050_000,
            display_name: "GPT-5.6 Luna",
            max_output_tokens: 128_000,
            input_cost: 1.0,
            cached_input_cost: 0.10,
            cache_write_cost: 1.25,
            output_cost: 6.0,
            vision_enabled: true,
            endpoint: "https://api.openai.com/v1/responses",
          },
        ],
      )
    end

    it "marks every Anthropic model known to require adaptive-only thinking" do
      %w[claude-opus-4-7 claude-opus-4-8 claude-sonnet-5].each do |name|
        model = described_class.find_model("anthropic", name)
        expect(model[:provider_params]).to eq(enable_reasoning: true, adaptive_thinking: true),
        "expected #{name} preset to require adaptive thinking"
      end
    end
  end
end
