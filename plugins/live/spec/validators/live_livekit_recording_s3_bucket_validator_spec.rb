# frozen_string_literal: true

RSpec.describe LiveLivekitRecordingS3BucketValidator do
  subject(:validator) { described_class.new }

  before do
    SiteSetting.live_livekit_url = "wss://livekit.example.com"
    SiteSetting.live_livekit_recording_s3_access_key_id = "recording-access-key"
    SiteSetting.live_livekit_recording_s3_secret_access_key = "recording-secret-key"
  end

  it "accepts an empty bucket for self-hosted storage" do
    SiteSetting.live_livekit_recording_s3_secret_access_key = ""

    expect(validator.valid_value?("")).to eq(true)
  end

  it "accepts a bucket when the recording credentials and region are configured" do
    expect(validator.valid_value?("live-recordings")).to eq(true)
  end

  it "validates the configured bucket name regex when saving the setting" do
    ["live-recordings/folder", "Live-recordings", "ab", "a" * 64].each do |bucket|
      expect { SiteSetting.live_livekit_recording_s3_bucket = bucket }.to raise_error(
        Discourse::InvalidParameters,
        "live_livekit_recording_s3_bucket: #{I18n.t("site_settings.errors.regex_mismatch")}",
      )
    end

    SiteSetting.live_livekit_recording_s3_bucket = "live-recordings"
    expect(SiteSetting.live_livekit_recording_s3_bucket).to eq("live-recordings")

    SiteSetting.live_livekit_recording_s3_bucket = ""
    expect(SiteSetting.live_livekit_recording_s3_bucket).to eq("")
  end

  it "requires both recording credentials" do
    SiteSetting.live_livekit_recording_s3_access_key_id = ""
    expect(validator.valid_value?("live-recordings")).to eq(false)

    SiteSetting.live_livekit_recording_s3_access_key_id = "recording-access-key"
    SiteSetting.live_livekit_recording_s3_secret_access_key = ""
    expect(validator.valid_value?("live-recordings")).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("site_settings.errors.live_livekit_recording_s3_requires_credentials"),
    )
  end

  it "requires a region unless a custom endpoint is configured" do
    SiteSetting.live_livekit_recording_s3_region = ""

    expect(validator.valid_value?("live-recordings")).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("site_settings.errors.live_livekit_recording_s3_requires_region"),
    )

    SiteSetting.live_livekit_recording_s3_endpoint = "https://storage.example.com"
    expect(validator.valid_value?("live-recordings")).to eq(true)
  end

  it "requires an encrypted connection to LiveKit" do
    SiteSetting.live_livekit_url = "ws://livekit.example.com"

    expect(validator.valid_value?("live-recordings")).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("site_settings.errors.live_livekit_recording_s3_requires_wss"),
    )
  end
end
