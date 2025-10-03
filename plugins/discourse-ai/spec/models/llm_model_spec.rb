# frozen_string_literal: true

RSpec.describe LlmModel do
  before { enable_current_plugin }

  describe "api_key" do
    fab!(:llm_model) { Fabricate(:seeded_model) }

    before { ENV["DISCOURSE_AI_SEEDED_LLM_API_KEY_2"] = "blabla" }

    it "should use environment variable over database value if seeded LLM" do
      expect(llm_model.api_key).to eq("blabla")
    end
  end
end
