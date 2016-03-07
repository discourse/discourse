require 'rails_helper'
require_dependency "common_passwords/common_passwords"

describe PasswordValidator do

  let(:validator) { described_class.new({attributes: :password}) }
  subject(:validate) { validator.validate_each(record,:password,@password) }

  context "password required" do
    let(:record) { u = Fabricate.build(:user, password: @password); u.password_required!; u }

    context "password is not common" do
      before do
        CommonPasswords.stubs(:common_password?).returns(false)
      end

      context "min password length is 8" do
        before { SiteSetting.stubs(:min_password_length).returns(8) }

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
        before { SiteSetting.stubs(:min_password_length).returns(12) }

        it "adds an error when password length is 11" do
          @password = "gt38sdt92bv"
          validate
          expect(record.errors[:password]).to be_present
        end
      end
    end

    context "password is commonly used" do
      before do
        SiteSetting.stubs(:min_password_length).returns(8)
        CommonPasswords.stubs(:common_password?).returns(true)
      end

      it "adds an error when block_common_passwords is enabled" do
        SiteSetting.stubs(:block_common_passwords).returns(true)
        @password = "password"
        validate
        expect(record.errors[:password]).to be_present
      end

      it "doesn't add an error when block_common_passwords is disabled" do
        SiteSetting.stubs(:block_common_passwords).returns(false)
        @password = "password"
        validate
        expect(record.errors[:password]).not_to be_present
      end
    end

    it "adds an error when password is the same as the username" do
      @password = "porkchops1234"
      record.username = @password
      validate
      expect(record.errors[:password]).to be_present
    end

    it "adds an error when password is the same as the email" do
      @password = "pork@chops.com"
      record.email = @password
      validate
      expect(record.errors[:password]).to be_present
    end
  end

  context "password not required" do
    let(:record) { Fabricate.build(:user, password: @password) }

    it "doesn't add an error if password is not required" do
      @password = nil
      validate
      expect(record.errors[:password]).not_to be_present
    end
  end

end
