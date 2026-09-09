# frozen_string_literal: true

RSpec.describe VoiceLivekitRecordingS3BucketValidator do
  subject(:validator) { described_class.new }

  before do
    SiteSetting.voice_livekit_url = "wss://livekit.example.com"
    SiteSetting.voice_livekit_recording_s3_access_key_id = "recording-access-key"
    SiteSetting.voice_livekit_recording_s3_secret_access_key = "recording-secret-key"
  end

  it "accepts an empty bucket for self-hosted storage" do
    SiteSetting.voice_livekit_recording_s3_secret_access_key = ""

    expect(validator.valid_value?("")).to eq(true)
  end

  it "accepts a bucket when the recording credentials and region are configured" do
    expect(validator.valid_value?("voice-recordings")).to eq(true)
  end

  it "requires both recording credentials" do
    SiteSetting.voice_livekit_recording_s3_access_key_id = ""
    expect(validator.valid_value?("voice-recordings")).to eq(false)

    SiteSetting.voice_livekit_recording_s3_access_key_id = "recording-access-key"
    SiteSetting.voice_livekit_recording_s3_secret_access_key = ""
    expect(validator.valid_value?("voice-recordings")).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("site_settings.errors.voice_livekit_recording_s3_requires_credentials"),
    )
  end

  it "requires a region unless a custom endpoint is configured" do
    SiteSetting.voice_livekit_recording_s3_region = ""

    expect(validator.valid_value?("voice-recordings")).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("site_settings.errors.voice_livekit_recording_s3_requires_region"),
    )

    SiteSetting.voice_livekit_recording_s3_endpoint = "https://storage.example.com"
    expect(validator.valid_value?("voice-recordings")).to eq(true)
  end

  it "requires an encrypted connection to LiveKit" do
    SiteSetting.voice_livekit_url = "ws://livekit.example.com"

    expect(validator.valid_value?("voice-recordings")).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("site_settings.errors.voice_livekit_recording_s3_requires_wss"),
    )
  end
end
