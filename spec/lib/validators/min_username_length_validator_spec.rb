# frozen_string_literal: true

RSpec.describe MinUsernameLengthValidator do
  it "checks for maximum range" do
    SiteSetting.max_username_length = 10

    validator = described_class.new
    expect(validator.valid_value?(11)).to eq(false)
    expect(validator.error_message).to eq(I18n.t("site_settings.errors.min_username_length_range"))
  end

  describe "checks for valid ranges" do
    it "fails for values below the valid range" do
      expect { SiteSetting.min_username_length = 0 }.to raise_error(Discourse::InvalidParameters)

      validator = described_class.new
      expect(validator.valid_value?(0)).to eq(false)
      expect(validator.error_message).to eq(
        I18n.t(
          "site_settings.errors.invalid_integer_min_max",
          min: MinUsernameLengthValidator::MIN_USERNAME_LENGTH_RANGE.begin,
          max: MinUsernameLengthValidator::MIN_USERNAME_LENGTH_RANGE.end,
        ),
      )
    end

    it "fails for values above the valid range" do
      expect { SiteSetting.min_username_length = 61 }.to raise_error(Discourse::InvalidParameters)

      validator = described_class.new
      expect(validator.valid_value?(61)).to eq(false)
      expect(validator.error_message).to eq(
        I18n.t(
          "site_settings.errors.invalid_integer_min_max",
          min: MinUsernameLengthValidator::MIN_USERNAME_LENGTH_RANGE.begin,
          max: MinUsernameLengthValidator::MIN_USERNAME_LENGTH_RANGE.end,
        ),
      )
    end

    it "works for values within the valid range" do
      expect { SiteSetting.min_username_length = 4 }.not_to raise_error

      validator = described_class.new
      expect(validator.valid_value?(4)).to eq(true)
    end
  end

  it "checks for users with short usernames" do
    Fabricate(:user, username: "jack")

    validator = described_class.new
    expect(validator.valid_value?(4)).to eq(true)

    validator = described_class.new
    expect(validator.valid_value?(5)).to eq(false)

    expect(validator.error_message).to eq(
      I18n.t("site_settings.errors.min_username_length_exists", username: "jack"),
    )
  end
end
