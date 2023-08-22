# frozen_string_literal: true

RSpec.describe ExternalSystemAvatarsValidator do
  subject(:validator) { described_class.new }

  it "disallows disabling external system avatars when Unicode usernames are enabled" do
    SiteSetting.unicode_usernames = true

    expect(validator.valid_value?("f")).to eq(false)
    expect(validator.error_message).to eq(I18n.t("site_settings.errors.unicode_usernames_avatars"))

    expect(validator.valid_value?("t")).to eq(true)
    expect(validator.error_message).to be_blank
  end

  it "allows disabling external system avatars when Unicode usernames are disabled" do
    SiteSetting.unicode_usernames = false

    expect(validator.valid_value?("t")).to eq(true)
    expect(validator.error_message).to be_blank

    expect(validator.valid_value?("f")).to eq(true)
    expect(validator.error_message).to be_blank
  end
end
