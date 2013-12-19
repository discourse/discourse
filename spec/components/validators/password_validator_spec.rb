require 'spec_helper'

describe PasswordValidator do

  let(:validator) { described_class.new({attributes: :password}) }
  subject(:validate) { validator.validate_each(record,:password,@password) }

  context "password required" do
    let(:record) { u = Fabricate.build(:user, password: @password); u.password_required!; u }

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

  context "password not required" do
    let(:record) { Fabricate.build(:user, password: @password) }

    it "doesn't add an error if password is not required" do
      @password = nil
      validate
      record.errors[:password].should_not be_present
    end
  end

end
