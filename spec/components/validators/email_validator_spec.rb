require 'spec_helper'

describe EmailValidator do

  let(:record) { Fabricate.build(:user, email: "bad@spamclub.com") }
  let(:validator) { described_class.new({attributes: :email}) }
  subject(:validate) { validator.validate_each(record,:email,record.email) }

  context "blocked email" do
    it "doesn't add an error when email doesn't match a blocked email" do
      ScreenedEmail.stubs(:should_block?).with(record.email).returns(false)
      validate
      record.errors[:email].should_not be_present
    end

    it "adds an error when email matches a blocked email" do
      ScreenedEmail.stubs(:should_block?).with(record.email).returns(true)
      validate
      record.errors[:email].should be_present
    end
  end

end
