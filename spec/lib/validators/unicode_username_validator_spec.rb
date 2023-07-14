# frozen_string_literal: true

RSpec.describe UnicodeUsernameValidator do
  subject(:validator) { described_class.new }

  it "disallows Unicode usernames when external system avatars are disabled" do
    SiteSetting.external_system_avatars_enabled = false

    expect(validator.valid_value?("t")).to eq(false)
    expect(validator.error_message).to eq(I18n.t("site_settings.errors.unicode_usernames_avatars"))

    expect(validator.valid_value?("f")).to eq(true)
    expect(validator.error_message).to be_blank
  end

  it "allows Unicode usernames when external system avatars are enabled" do
    SiteSetting.external_system_avatars_enabled = true

    expect(validator.valid_value?("t")).to eq(true)
    expect(validator.error_message).to be_blank

    expect(validator.valid_value?("f")).to eq(true)
    expect(validator.error_message).to be_blank
  end
end
