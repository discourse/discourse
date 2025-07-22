# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::LlmValidator do
  before { enable_current_plugin }

  describe "#valid_value?" do
    context "when the parent module is enabled and we try to reset the selected model" do
      before do
        assign_fake_provider_to(:ai_summarization_model)
        SiteSetting.ai_summarization_enabled = true
      end

      it "returns false and displays an error message" do
        validator = described_class.new(name: :ai_summarization_model)

        value = validator.valid_value?("")

        expect(value).to eq(false)
        expect(validator.error_message).to include("ai_summarization_enabled")
      end
    end
  end
end
