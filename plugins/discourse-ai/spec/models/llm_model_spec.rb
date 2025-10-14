# frozen_string_literal: true

RSpec.describe LlmModel do
  before { enable_current_plugin }

  describe "api_key" do
    fab!(:llm_model, :seeded_model)

    before { ENV["DISCOURSE_AI_SEEDED_LLM_API_KEY_2"] = "blabla" }

    it "should use environment variable over database value if seeded LLM" do
      expect(llm_model.api_key).to eq("blabla")
    end
  end

  describe "#credit_system_enabled?" do
    fab!(:seeded_model)
    fab!(:regular_model, :llm_model)

    it "returns false for non-seeded models" do
      expect(regular_model.credit_system_enabled?).to be false
    end

    it "returns false for seeded models without credit allocation" do
      expect(seeded_model.credit_system_enabled?).to be false
    end

    it "returns true for seeded models with credit allocation" do
      Fabricate(:llm_credit_allocation, llm_model: seeded_model)
      expect(seeded_model.credit_system_enabled?).to be true
    end
  end
end
