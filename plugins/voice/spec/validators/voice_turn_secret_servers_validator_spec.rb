# frozen_string_literal: true

RSpec.describe VoiceTurnSecretServersValidator do
  subject(:validator) { described_class.new }

  it "always accepts a blank value" do
    expect(validator.valid_value?("")).to eq(true)
    expect(validator.valid_value?(nil)).to eq(true)
  end

  it "accepts server urls when the TURN secret is configured" do
    SiteSetting.voice_turn_secret = "coturn-shared-secret"

    expect(validator.valid_value?("turn:coturn.example.com:3478")).to eq(true)
  end

  it "rejects server urls when the TURN secret is blank" do
    expect(validator.valid_value?("turn:coturn.example.com:3478")).to eq(false)
    expect(validator.error_message).to eq(
      I18n.t("site_settings.errors.voice_turn_secret_servers_requires_secret"),
    )
  end
end
