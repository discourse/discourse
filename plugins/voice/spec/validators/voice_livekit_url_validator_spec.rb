# frozen_string_literal: true

RSpec.describe VoiceLivekitUrlValidator do
  subject(:validator) { described_class.new }

  it "accepts a blank value" do
    expect(validator.valid_value?("")).to eq(true)
    expect(validator.valid_value?(nil)).to eq(true)
  end

  it "accepts ws:// and wss:// origins outside production" do
    expect(validator.valid_value?("wss://livekit.example.com")).to eq(true)
    expect(validator.valid_value?("ws://livekit.internal:7880")).to eq(true)
  end

  it "rejects URLs that are not ws(s)://, have no host, or embed credentials" do
    [
      "https://livekit.example.com",
      "wss://",
      "wss://user:pass@livekit.example.com",
      "not a url",
    ].each do |value|
      expect(validator.valid_value?(value)).to eq(false)
      expect(validator.error_message).to eq(
        I18n.t("site_settings.errors.voice_livekit_url_invalid"),
      )
    end
  end

  it "requires wss:// in production" do
    Rails.env.stubs(:production?).returns(true)

    expect(validator.valid_value?("wss://livekit.example.com")).to eq(true)
    expect(validator.valid_value?("ws://livekit.example.com")).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("site_settings.errors.voice_livekit_url_requires_wss"),
    )
  end

  describe ".acceptable?" do
    it "requires a present, valid URL" do
      expect(described_class.acceptable?("")).to eq(false)
      expect(described_class.acceptable?("https://livekit.example.com")).to eq(false)
      expect(described_class.acceptable?("wss://livekit.example.com")).to eq(true)
    end
  end
end
