require 'spec_helper'

describe AllowedIpAddressValidator do

  let(:record) { Fabricate.build(:user, trust_level: TrustLevel[0], ip_address: '99.232.23.123') }
  let(:validator) { described_class.new({attributes: :ip_address}) }
  subject(:validate) { validator.validate_each(record, :ip_address, record.ip_address) }

  context "ip address should be blocked" do
    it 'should add an error' do
      ScreenedIpAddress.stubs(:should_block?).returns(true)
      validate
      record.errors[:ip_address].should be_present
    end
  end

  context "ip address isn't allowed for registration" do
    it 'should add an error' do
      SpamHandler.stubs(:should_prevent_registration_from_ip?).returns(true)
      validate
      record.errors[:ip_address].should be_present
    end
  end

  context "ip address should not be blocked" do
    it "shouldn't add an error" do
      ScreenedIpAddress.stubs(:should_block?).returns(false)
      validate
      record.errors[:ip_address].should_not be_present
    end
  end

  context 'ip_address is nil' do
    it "shouldn't add an error" do
      ScreenedIpAddress.expects(:should_block?).never
      record.ip_address = nil
      validate
      record.errors[:ip_address].should_not be_present
    end
  end

end
