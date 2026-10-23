# frozen_string_literal: true

describe DiscourseAi::Configuration::AskAiSummaryDetailEnumerator do
  describe ".values" do
    it "provides translated labels for the supported detail levels" do
      expect(described_class.values).to eq(
        [
          { name: "admin.site_settings.ai_ask_ai_summary_detail.quiet", value: "quiet" },
          { name: "admin.site_settings.ai_ask_ai_summary_detail.balanced", value: "balanced" },
          { name: "admin.site_settings.ai_ask_ai_summary_detail.detailed", value: "detailed" },
        ],
      )
      expect(described_class.translate_names?).to eq(true)
    end
  end

  describe ".valid_value?" do
    it "accepts the supported detail levels" do
      supported_values = %w[quiet balanced detailed]
      valid_values = supported_values.select { |value| described_class.valid_value?(value) }

      expect(valid_values).to eq(supported_values)
    end

    it "rejects unsupported detail levels" do
      expect(described_class.valid_value?("prominent")).to eq(false)
    end
  end
end
