# frozen_string_literal: true

RSpec.describe MaxUsernameLengthValidator do
  it "checks for minimum range" do
    User.update_all("username = username || username")
    SiteSetting.min_username_length = 9

    validator = described_class.new
    expect(validator.valid_value?(8)).to eq(false)
    expect(validator.error_message).to eq(I18n.t("site_settings.errors.max_username_length_range"))
  end

  describe "checks for valid ranges" do
    it "fails for values below the valid range" do
      expect { SiteSetting.max_username_length = 5 }.to raise_error(Discourse::InvalidParameters)

      validator = described_class.new
      expect(validator.valid_value?(5)).to eq(false)
      expect(validator.error_message).to eq(
        I18n.t(
          "site_settings.errors.invalid_integer_min_max",
          min: MaxUsernameLengthValidator::MAX_USERNAME_LENGTH_RANGE.begin,
          max: MaxUsernameLengthValidator::MAX_USERNAME_LENGTH_RANGE.end,
        ),
      )
    end

    it "fails for values above the valid range" do
      expect { SiteSetting.max_username_length = 61 }.to raise_error(Discourse::InvalidParameters)

      validator = described_class.new
      expect(validator.valid_value?(61)).to eq(false)
      expect(validator.error_message).to eq(
        I18n.t(
          "site_settings.errors.invalid_integer_min_max",
          min: MaxUsernameLengthValidator::MAX_USERNAME_LENGTH_RANGE.begin,
          max: MaxUsernameLengthValidator::MAX_USERNAME_LENGTH_RANGE.end,
        ),
      )
    end

    it "works for values within the valid range" do
      expect { SiteSetting.max_username_length = 42 }.not_to raise_error

      validator = described_class.new
      expect(validator.valid_value?(42)).to eq(true)
    end
  end

  it "checks for users with short usernames" do
    Fabricate(:user, username: "jackjackjack")

    validator = described_class.new
    expect(validator.valid_value?(12)).to eq(true)

    validator = described_class.new
    expect(validator.valid_value?(11)).to eq(false)

    expect(validator.error_message).to eq(
      I18n.t("site_settings.errors.max_username_length_exists", username: "jackjackjack"),
    )
  end
end
