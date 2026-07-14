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

      DiscourseAi::Completions::Llm.with_prepared_responses(%w[ok ok]) do
        expect(validator.valid_value?(llm_model)).to eq(true)
      end
    end
  end

  describe "#run_test" do
    let(:validator) { described_class.new }
    fab!(:llm_model)

    it "exercises both non-streaming and streaming completions" do
      prompts =
        DiscourseAi::Completions::Llm.with_prepared_responses(%w[ok ok]) do |_, _, p|
          validator.run_test(llm_model)
          p
        end

      expect(prompts.length).to eq(2)
      expect(validator.last_failed_mode).to be_nil
    end

    it "marks non-streaming failure when the first probe returns nothing" do
      DiscourseAi::Completions::Llm.with_prepared_responses(["", "ok"]) do
        expect { validator.run_test(llm_model) }.to raise_error(
          DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
        )
      end

      expect(validator.last_failed_mode).to eq(:non_streaming)
    end

    it "marks streaming failure when the streaming probe returns nothing" do
      DiscourseAi::Completions::Llm.with_prepared_responses(["ok", ""]) do
        expect { validator.run_test(llm_model) }.to raise_error(
          DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
        )
      end

      expect(validator.last_failed_mode).to eq(:streaming)
    end
  end
end
