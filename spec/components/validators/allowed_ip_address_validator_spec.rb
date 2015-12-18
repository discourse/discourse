require 'rails_helper'

describe AllowedIpAddressValidator do

  let(:record) { Fabricate.build(:user, trust_level: TrustLevel[0], ip_address: '99.232.23.123') }
  let(:validator) { described_class.new({attributes: :ip_address}) }
  subject(:validate) { validator.validate_each(record, :ip_address, record.ip_address) }

  context "ip address should be blocked" do
    it 'should add an error' do
      ScreenedIpAddress.stubs(:should_block?).returns(true)
      validate
      expect(record.errors[:ip_address]).to be_present
      expect(record.errors[:ip_address][0]).to eq(I18n.t('user.ip_address.blocked'))
    end
  end

  context "ip address isn't allowed for registration" do
    it 'should add an error' do
      SpamHandler.stubs(:should_prevent_registration_from_ip?).returns(true)
      validate
      expect(record.errors[:ip_address]).to be_present
      expect(record.errors[:ip_address][0]).to eq(I18n.t('user.ip_address.max_new_accounts_per_registration_ip'))
    end
  end

  context "ip address should not be blocked" do
    it "shouldn't add an error" do
      ScreenedIpAddress.stubs(:should_block?).returns(false)
      validate
      expect(record.errors[:ip_address]).not_to be_present
    end
  end

  context 'ip_address is nil' do
    it "shouldn't add an error" do
      ScreenedIpAddress.expects(:should_block?).never
      record.ip_address = nil
      validate
      expect(record.errors[:ip_address]).not_to be_present
    end
  end

end
