# frozen_string_literal: true

RSpec.describe LanguageSwitcherSettingValidator do
  subject(:validator) { described_class.new }

  it "always allows disabling the switcher" do
    SiteSetting.allow_user_locale = false
    SiteSetting.content_localization_supported_locales = ""

    expect(validator.valid_value?("none")).to eq(true)
  end

  context "when enabling the switcher" do
    before { SiteSetting.content_localization_supported_locales = "es|fr" }

    it "does not require the locale cookie setting" do
      SiteSetting.set_locale_from_cookie = false

      expect(validator.valid_value?("all")).to eq(true)
      expect(validator.valid_value?("anonymous")).to eq(true)
    end

    it "requires allow_user_locale" do
      SiteSetting.allow_user_locale = false

      expect(validator.valid_value?("all")).to eq(false)
    end

    it "requires at least one supported locale" do
      SiteSetting.content_localization_supported_locales = ""

      expect(validator.valid_value?("all")).to eq(false)
    end
  end

  it "links the remaining requirements from its error message" do
    expect(validator.error_message).to include(
      "{{setting:allow_user_locale}}",
      "{{setting:content_localization_supported_locales}}",
    )
    expect(validator.error_message).not_to include("set_locale_from_cookie")
  end
end
