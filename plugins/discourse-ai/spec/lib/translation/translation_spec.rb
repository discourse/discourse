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

  describe ".credits_available_for_site_setting_localization?" do
    it "checks credits for short text and post raw translators" do
      short_text_model = Fabricate(:llm_model)
      post_raw_model = Fabricate(:llm_model)
      short_text_agent = Fabricate(:ai_agent)
      post_raw_agent = Fabricate(:ai_agent)
      short_text_agent.update!(default_llm_id: short_text_model.id)
      post_raw_agent.update!(default_llm_id: post_raw_model.id)
      SiteSetting.ai_translation_short_text_translator_agent = short_text_agent.id
      SiteSetting.ai_translation_post_raw_translator_agent = post_raw_agent.id

      LlmCreditAllocation.stubs(:credits_available?).with(short_text_model).returns(true)
      LlmCreditAllocation.stubs(:credits_available?).with(post_raw_model).returns(false)

      expect(described_class.credits_available_for_site_setting_localization?).to eq(false)
    end
  end
end
