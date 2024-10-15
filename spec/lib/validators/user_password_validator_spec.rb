# frozen_string_literal: true

RSpec.describe UserPasswordValidator do
  def password_error_message(key)
    I18n.t("activerecord.errors.models.user_password.attributes.password.#{key}")
  end

  subject(:validate) { validator.validate_each(record, :password, @password) }

  let(:validator) { described_class.new(attributes: :password) }

  # fabrication doesn't work here as it somehow bypasses the password= setter logic
  let(:record) do
    UserPassword.build(password: @password, user: Fabricate.build(:user, password: nil))
  end

  context "when password is not common" do
    before { CommonPasswords.stubs(:common_password?).returns(false) }

    context "when min password length is 8" do
      before { SiteSetting.min_password_length = 8 }

      it "doesn't add an error when password is good" do
        @password = "weron235alsfn234"
        validate
        expect(record.errors[:password]).not_to be_present
      end

      it "adds an error when password is too short" do
        @password = "p"
        validate
        expect(record.errors[:password]).to be_present
      end

      it "adds an error when user is admin and password is less than 15 chars" do
        SiteSetting.min_admin_password_length = 15

        @password = "12345678912"
        record.user.admin = true
        validate
        expect(record.errors[:password]).to be_present
      end
    end

    context "when min password length is 12" do
      before { SiteSetting.min_password_length = 12 }

      it "adds an error when password length is 11" do
        @password = "gt38sdt92bv"
        validate
        expect(record.errors[:password]).to be_present
      end
    end
  end
  context "when password is commonly used" do
    before do
      SiteSetting.min_password_length = 8
      CommonPasswords.stubs(:common_password?).returns(true)
    end

    it "adds an error when block_common_passwords is enabled" do
      SiteSetting.block_common_passwords = true
      @password = "password"
      validate
      expect(record.errors[:password]).to include(password_error_message(:common))
    end

    it "doesn't add an error when block_common_passwords is disabled" do
      SiteSetting.block_common_passwords = false
      @password = "password"
      validate
      expect(record.errors[:password]).not_to be_present
    end
  end

  context "when password_unique_characters is 5" do
    before { SiteSetting.password_unique_characters = 5 }

    it "adds an error when there are too few unique characters" do
      SiteSetting.password_unique_characters = 6
      @password = "aaaaaa5432"
      validate
      expect(record.errors[:password]).to include(password_error_message(:unique_characters))
    end

    it "doesn't add an error when there are enough unique characters" do
      @password = "aaaaa12345"
      validate
      expect(record.errors[:password]).not_to be_present
    end

    it "counts capital letters as different" do
      @password = "aaaAaa1234"
      validate
      expect(record.errors[:password]).not_to be_present
    end
  end

  it "adds an error when password is the same as the username" do
    @password = "porkchops1234"
    record.user.username = @password
    validate
    expect(record.errors[:password]).to include(password_error_message(:same_as_username))
  end

  it "adds an error when password is the same as the name" do
    @password = "myawesomepassword"
    record.user.name = @password
    validate
    expect(record.errors[:password]).to include(password_error_message(:same_as_name))
  end

  it "adds an error when password is the same as the email" do
    @password = "pork@chops.com"
    record.user.email = @password
    validate
    expect(record.errors[:password]).to include(password_error_message(:same_as_email))
  end

  it "adds an error when new password is same as current password" do
    @password = "mypetsname"
    record.save!
    record.reload
    record.password = @password
    validate

    expect(record.errors[:password]).to include(password_error_message(:same_as_current))
  end
end
