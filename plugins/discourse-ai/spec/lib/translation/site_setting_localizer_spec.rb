# frozen_string_literal: true

describe DiscourseAi::Translation::SiteSettingLocalizer do
  subject(:localizer) { described_class }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.default_locale = "en"
  end

  def translator_stub(translator_class, text:, target_locale:, translated:)
    translator = instance_double(translator_class)
    allow(translator_class).to receive(:new).with(
      text:,
      target_locale:,
      llm_model: be_nil,
    ).and_return(translator)
    allow(translator).to receive(:translate).and_return(translated)
  end

  describe ".localize" do
    it "translates short text settings" do
      SiteSetting.title = "English community"
      translator_stub(
        DiscourseAi::Translation::ShortTextTranslator,
        text: "English community",
        target_locale: "ja",
        translated: "日本語コミュニティ",
      )

      localization = localizer.localize("title", "ja")

      expect(localization).to have_attributes(
        setting_name: "title",
        locale: "ja",
        value: "日本語コミュニティ",
        localizer_user_id: Discourse::SYSTEM_USER_ID,
      )
    end

    it "translates markdown settings and stores cooked content" do
      SiteSetting.extended_site_description = "**English** description"
      translator_stub(
        DiscourseAi::Translation::PostRawTranslator,
        text: "**English** description",
        target_locale: "ja",
        translated: "**日本語**の説明",
      )

      localization = localizer.localize("extended_site_description", "ja")

      expect(localization.value).to eq("**日本語**の説明")
      expect(localization.cooked).to include("<strong>日本語</strong>")
    end

    it "updates an existing localization" do
      SiteSetting.title = "English community"
      existing =
        SiteSettingLocalization.create!(setting_name: "title", locale: "ja", value: "古いタイトル")
      translator_stub(
        DiscourseAi::Translation::ShortTextTranslator,
        text: "English community",
        target_locale: "ja",
        translated: "新しいタイトル",
      )

      expect { localizer.localize("title", "ja") }.not_to change { SiteSettingLocalization.count }

      expect(existing.reload.value).to eq("新しいタイトル")
    end

    it "skips settings that require manual localization" do
      SiteSetting.company_url = "https://example.com"
      DiscourseAi::Translation::ShortTextTranslator.expects(:new).never

      expect(localizer.localize("company_url", "ja")).to be_nil
    end

    it "skips invalid inputs" do
      SiteSetting.title = "English community"
      DiscourseAi::Translation::ShortTextTranslator.expects(:new).never

      expect(localizer.localize("missing_setting", "ja")).to be_nil
      expect(localizer.localize("title", nil)).to be_nil
      expect(localizer.localize("title", "en")).to be_nil
    end
  end
end
