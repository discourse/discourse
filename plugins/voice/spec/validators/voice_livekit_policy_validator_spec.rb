# frozen_string_literal: true

RSpec.describe VoiceLivekitPolicyValidator do
  subject(:validator) { described_class.new }

  it "always accepts the disabled policy, even unconfigured" do
    expect(validator.valid_value?("disabled")).to eq(true)
  end

  it "accepts a non-disabled policy when fully configured" do
    SiteSetting.voice_livekit_url = "wss://livekit.example.com"
    SiteSetting.voice_livekit_api_key = "lk_api_key"
    SiteSetting.voice_livekit_api_secret = "lk_api_secret"

    expect(validator.valid_value?("per_room")).to eq(true)
    expect(validator.valid_value?("all_rooms")).to eq(true)
  end

  it "rejects a non-disabled policy when the url is blank or invalid" do
    SiteSetting.voice_livekit_api_key = "lk_api_key"
    SiteSetting.voice_livekit_api_secret = "lk_api_secret"

    expect(validator.valid_value?("per_room")).to eq(false)

    # An invalid stored value (the URL validator refuses assignments, so this
    # can only be pre-existing data) still blocks policy activation.
    SiteSetting.stubs(:voice_livekit_url).returns("https://livekit.example.com")
    expect(validator.valid_value?("per_room")).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("site_settings.errors.voice_livekit_policy_requires_url"),
    )
  end

  it "rejects a non-disabled policy when the api key is missing" do
    SiteSetting.voice_livekit_url = "wss://livekit.example.com"
    SiteSetting.voice_livekit_api_secret = "lk_api_secret"

    expect(validator.valid_value?("all_rooms")).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("site_settings.errors.voice_livekit_policy_requires_api_key"),
    )
  end

  it "rejects a non-disabled policy when the api secret is missing" do
    SiteSetting.voice_livekit_url = "ws://livekit.internal:7880"
    SiteSetting.voice_livekit_api_key = "lk_api_key"

    expect(validator.valid_value?("all_rooms")).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("site_settings.errors.voice_livekit_policy_requires_api_secret"),
    )
  end
end
