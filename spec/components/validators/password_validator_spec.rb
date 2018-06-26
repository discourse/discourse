require 'rails_helper'
require_dependency "common_passwords/common_passwords"

describe PasswordValidator do

  def password_error_message(key)
    I18n.t("activerecord.errors.models.user.attributes.password.#{key.to_s}")
  end

  let(:validator) { described_class.new(attributes: :password) }
  subject(:validate) { validator.validate_each(record, :password, @password) }

  context "password required" do
    let(:record) { u = Fabricate.build(:user, password: @password); u.password_required!; u }

    context "password is not common" do
      before do
        CommonPasswords.stubs(:common_password?).returns(false)
      end

      context "min password length is 8" do
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

        it "adds an error when password is blank" do
          @password = ''
          validate
          expect(record.errors[:password]).to be_present
        end

        it "adds an error when password is nil" do
          @password = nil
          validate
          expect(record.errors[:password]).to be_present
        end

        it "adds an error when user is admin and password is less than 15 chars" do
          SiteSetting.min_admin_password_length = 15

          @password = "12345678912"
          record.admin = true
          validate
          expect(record.errors[:password]).to be_present
        end
      end

      context "min password length is 12" do
        before { SiteSetting.min_password_length = 12 }

        it "adds an error when password length is 11" do
          @password = "gt38sdt92bv"
          validate
          expect(record.errors[:password]).to be_present
        end
      end
    end

    context "password is commonly used" do
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

    context "password_unique_characters is 5" do
      before do
        SiteSetting.password_unique_characters = 5
      end

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
      record.username = @password
      validate
      expect(record.errors[:password]).to include(password_error_message(:same_as_username))
    end

    it "adds an error when password is the same as the email" do
      @password = "pork@chops.com"
      record.email = @password
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

    it "validation required if password is required" do
      expect(record.password_validation_required?).to eq(true)
    end

    it "validation not required after save until a new password is set" do
      @password = "myoldpassword"
      record.save!
      record.reload
      expect(record.password_validation_required?).to eq(false)
      record.password = "mynewpassword"
      expect(record.password_validation_required?).to eq(true)
    end
  end

  context "password not required" do
    let(:record) { Fabricate.build(:user, password: @password) }

    it "doesn't add an error if password is not required" do
      @password = nil
      validate
      expect(record.errors[:password]).not_to be_present
    end

    it "validation required if a password is set" do
      @password = "mygameshow"
      expect(record.password_validation_required?).to eq(true)
    end

    it "adds an error even password not required" do
      @password = "p"
      validate
      expect(record.errors[:password]).to be_present
    end
  end

end
