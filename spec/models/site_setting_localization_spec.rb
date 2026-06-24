# frozen_string_literal: true

describe SiteSettingLocalization do
  before { SiteSetting.content_localization_enabled = true }

  describe ".value_for" do
    it "returns the localized setting value for the locale" do
      SiteSetting.site_description = "English description"
      described_class.create!(setting_name: "site_description", locale: "ja", value: "日本語の説明")

      expect(described_class.value_for(:site_description, locale: "ja")).to eq("日本語の説明")
    end

    it "falls back to the site setting value" do
      SiteSetting.site_description = "English description"

      expect(described_class.value_for(:site_description, locale: "ja")).to eq(
        "English description",
      )
    end

    it "falls back to a matching base locale" do
      SiteSetting.site_description = "English description"
      described_class.create!(
        setting_name: "site_description",
        locale: "pt",
        value: "Descrição em português",
      )

      expect(described_class.value_for(:site_description, locale: "pt_BR")).to eq(
        "Descrição em português",
      )
    end

    it "normalizes hyphenated locale names" do
      SiteSetting.site_description = "English description"
      described_class.create!(
        setting_name: "site_description",
        locale: "pt-BR",
        value: "Descrição brasileira",
      )

      expect(described_class.value_for(:site_description, locale: "pt-BR")).to eq(
        "Descrição brasileira",
      )
    end

    it "returns the site setting value when showing original content" do
      SiteSetting.site_description = "English description"
      described_class.create!(setting_name: "site_description", locale: "ja", value: "日本語の説明")

      expect(described_class.value_for(:site_description, locale: "ja", show_original: true)).to eq(
        "English description",
      )
    end

    it "returns cooked content for markdown settings" do
      localization =
        described_class.create!(
          setting_name: "extended_site_description",
          locale: "ja",
          value: "これは **説明** です",
        )

      expect(
        described_class.value_for(:extended_site_description, locale: "ja", cooked: true),
      ).to eq(localization.cooked)
    end
  end

  it "rejects settings outside the allowlist" do
    localization =
      described_class.new(setting_name: "contact_email", locale: "ja", value: "example@example.com")

    expect(localization).to be_invalid
  end

  it "supports localizing URL settings manually" do
    expect(described_class.localizable?("company_url")).to eq(true)
  end

  it "returns only valid localizable settings" do
    described_class.register(:missing_site_setting)

    expect(described_class.localizable?("title")).to eq(true)
    expect(described_class.localizable?("company_url")).to eq(true)
    expect(described_class.localizable?("missing_site_setting")).to eq(false)
  ensure
    described_class.localizable_settings.delete("missing_site_setting")
  end

  it "rejects cooked content for plain text settings" do
    localization =
      described_class.new(
        setting_name: "site_description",
        locale: "ja",
        value: "日本語の説明",
        cooked: "<p>日本語の説明</p>",
      )

    expect(localization).to be_invalid
  end

  it "regenerates cooked content from the setting value" do
    localization =
      described_class.create!(
        setting_name: "extended_site_description",
        locale: "ja",
        value: "これは **安全** です",
      )

    localization.update!(cooked: "<script>alert('xss')</script>")

    expect(localization.reload.cooked).to include("<strong>安全</strong>")
    expect(localization.cooked).not_to include("<script>")
  end
end
