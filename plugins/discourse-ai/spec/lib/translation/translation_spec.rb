# frozen_string_literal: true

describe DiscourseAi::Translation do
  before do
    assign_fake_provider_to(:ai_default_llm_model)
    enable_current_plugin
    SiteSetting.ai_translation_enabled = true
  end

  describe ".locales" do
    it "delegates to SiteSetting.content_localization_locales" do
      SiteSetting.content_localization_supported_locales = "es|fr"
      SiteSetting.default_locale = "en"

      expect(described_class.locales).to eq(SiteSetting.content_localization_locales)
    end
  end
end
