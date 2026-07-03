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

    it "marks every Anthropic model known to require adaptive-only thinking" do
      %w[claude-opus-4-7 claude-opus-4-8 claude-sonnet-5].each do |name|
        model = described_class.find_model("anthropic", name)
        expect(model[:provider_params]).to eq(enable_reasoning: true, adaptive_thinking: true),
        "expected #{name} preset to require adaptive thinking"
      end
    end
  end
end
