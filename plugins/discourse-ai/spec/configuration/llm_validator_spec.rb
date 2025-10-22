# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::LlmValidator do
  before { enable_current_plugin }

  describe "#valid_value?" do
    let(:validator) { described_class.new(name: :ai_default_llm_model) }
    fab!(:llm_model)

    before do
      assign_fake_provider_to(:ai_default_llm_model)
      SiteSetting.ai_helper_enabled = false
      SiteSetting.ai_summarization_enabled = false
      SiteSetting.ai_embeddings_semantic_search_enabled = false
      SiteSetting.ai_translation_enabled = false
    end

    it "returns true when no modules are enabled and value is empty string" do
      expect(validator.valid_value?("")).to eq(true)
    end

    it "returns false when a module is enabled and value is empty string" do
      SiteSetting.ai_helper_enabled = true
      expect(validator.valid_value?("")).to eq(false)
      expect(validator.error_message).to include("ai_helper_enabled")
    end

    it "returns false when multiple modules are enabled and value is empty string" do
      SiteSetting.ai_helper_enabled = true
      SiteSetting.ai_summarization_enabled = true
      expect(validator.valid_value?("")).to eq(false)
      expect(validator.error_message).to include("ai_helper_enabled, ai_summarization_enabled")
    end

    it "returns true for non-empty values regardless of module state" do
      SiteSetting.ai_helper_enabled = true
      SiteSetting.ai_summarization_enabled = true

      DiscourseAi::Completions::Llm.with_prepared_responses([true]) do
        expect(validator.valid_value?(llm_model)).to eq(true)
      end
    end
  end
end
