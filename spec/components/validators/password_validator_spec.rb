require 'spec_helper'
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
          record.errors[:password].should_not be_present
        end

        it "adds an error when password is too short" do
          @password = "p"
          validate
          record.errors[:password].should be_present
        end

        it "adds an error when password is blank" do
          @password = ''
          validate
          record.errors[:password].should be_present
        end

        it "adds an error when password is nil" do
          @password = nil
          validate
          record.errors[:password].should be_present
        end
      end

      context "min password length is 12" do
        before { SiteSetting.stubs(:min_password_length).returns(12) }

        it "adds an error when password length is 11" do
          @password = "gt38sdt92bv"
          validate
          record.errors[:password].should be_present
        end
      end
    end

    context "password is commonly used" do
      before do
        CommonPasswords.stubs(:common_password?).returns(true)
      end

      it "adds an error when block_common_passwords is enabled" do
        SiteSetting.stubs(:block_common_passwords).returns(true)
        @password = "password"
        validate
        record.errors[:password].should be_present
      end

      it "doesn't add an error when block_common_passwords is disabled" do
        SiteSetting.stubs(:block_common_passwords).returns(false)
        @password = "password"
        validate
        record.errors[:password].should_not be_present
      end
    end
  end

  context "password not required" do
    let(:record) { Fabricate.build(:user, password: @password) }

    it "doesn't add an error if password is not required" do
      @password = nil
      validate
      record.errors[:password].should_not be_present
    end
  end

end
