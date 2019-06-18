# frozen_string_literal: true

require 'rails_helper'

describe MinUsernameLengthValidator do
  it "checks for maximum range" do
    SiteSetting.max_username_length = 10

    validator = described_class.new
    expect(validator.valid_value?(11)).to eq(false)
    expect(validator.error_message).to eq(I18n.t("site_settings.errors.min_username_length_range"))
  end

  it "checks for users with short usernames" do
    user = Fabricate(:user, username: 'jack')

    validator = described_class.new
    expect(validator.valid_value?(4)).to eq(true)

    validator = described_class.new
    expect(validator.valid_value?(5)).to eq(false)

    expect(validator.error_message).to eq(I18n.t(
      "site_settings.errors.min_username_length_exists",
      username: 'jack'
    ))
  end
end
