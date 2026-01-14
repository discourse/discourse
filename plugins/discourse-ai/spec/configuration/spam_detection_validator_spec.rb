# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::SpamDetectionValidator do
  let(:validator) { described_class.new }

  before { enable_current_plugin }

  it "always returns true if setting the value to false" do
    expect(validator.valid_value?("f")).to eq(true)
  end

  context "when a moderation setting exists" do
    fab!(:llm_model)
    before { AiModerationSetting.create!(setting_type: "spam", llm_model_id: llm_model.id) }

    it "returns true if a moderation setting for spam exists" do
      expect(validator.valid_value?("t")).to eq(true)
    end
  end

  context "when no moderation setting exists" do
    it "returns false if a moderation setting for spam does not exist" do
      expect(validator.valid_value?("t")).to eq(false)
    end

    it "returns an error message when no moderation setting exists" do
      expect(validator.error_message).to eq(
        I18n.t("discourse_ai.spam_detection.configuration_missing"),
      )
    end
  end
end
