# frozen_string_literal: true

describe ContentLocalizationCrawlerParamValidator do
  subject(:validator) { described_class.new }

  it "allows the setting to be disabled" do
    expect(validator.valid_value?("f")).to eq(true)
  end

  it "rejects enabling when locale params are disabled" do
    SiteSetting.set_locale_from_param = false

    expect(validator.valid_value?("t")).to eq(false)
  end

  it "allows enabling when locale params are enabled" do
    SiteSetting.allow_user_locale = true
    SiteSetting.set_locale_from_param = true

    expect(validator.valid_value?("t")).to eq(true)
  end
end
