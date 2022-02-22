# frozen_string_literal: true

require 'rails_helper'

describe ScreenedIpAddress do
  let(:ip_address) { '99.232.23.124' }
  let(:valid_params) { { ip_address: ip_address } }

  describe 'new record' do
    it 'sets a default action_type' do
      expect(described_class.create(valid_params).action_type).to eq(described_class.actions[:block])
    end

    it 'sets an error when ip_address is invalid' do
      expect(described_class.create(valid_params.merge(ip_address: '99.99.99')).errors[:ip_address]).to be_present
    end

    it 'can set action_type using the action_name virtual attribute' do
      expect(described_class.new(valid_params.merge(action_name: :do_nothing)).action_type).to eq(described_class.actions[:do_nothing])
      expect(described_class.new(valid_params.merge(action_name: :block)).action_type).to eq(described_class.actions[:block])
      expect(described_class.new(valid_params.merge(action_name: 'do_nothing')).action_type).to eq(described_class.actions[:do_nothing])
      expect(described_class.new(valid_params.merge(action_name: 'block')).action_type).to eq(described_class.actions[:block])
    end

    it 'raises a useful exception when action is invalid' do
      expect {
        described_class.new(valid_params.merge(action_name: 'dance'))
      }.to raise_error(ArgumentError)
    end

    it 'raises a useful exception when action is nil' do
      expect {
        described_class.new(valid_params.merge(action_name: nil))
      }.to raise_error(ArgumentError)
    end

    it 'returns a useful error if ip address matches an existing record' do
      ScreenedIpAddress.create(ip_address: '2600:387:b:f::7a/128', action_name: :block)
      r = ScreenedIpAddress.new(ip_address: '2600:387:b:f::7a', action_name: :block)
      expect(r.save).to eq(false)
      expect(r.errors[:ip_address]).to be_present
    end
  end

  describe "ip_address_with_mask" do
    it "returns nil when ip_address is nil" do
      expect(described_class.new.ip_address_with_mask).to eq(nil)
    end

    it "returns ip_address without mask if there is no mask" do
      expect(described_class.new(ip_address: "123.123.23.22").ip_address_with_mask).to eq("123.123.23.22")
    end

    it "returns ip_address with mask" do
      expect(described_class.new(ip_address: "123.12.0.0/16").ip_address_with_mask).to eq("123.12.0.0/16")
    end
  end

  describe "ip_address=" do
    let(:record) { described_class.new }

    def test_good_value(arg, expected)
      record.ip_address = arg
      expect(record.ip_address_with_mask).to eq(expected)
    end

    def test_bad_value(arg)
      r = described_class.new
      r.ip_address = arg
      expect(r).not_to be_valid
      expect(r.errors[:ip_address]).to be_present
    end

    it "handles valid ip addresses" do
      test_good_value("210.56.12.12", "210.56.12.12")
      test_good_value("210.56.0.0/16", "210.56.0.0/16")
      test_good_value("fc00::/7", "fc00::/7")
      test_good_value(IPAddr.new("94.99.101.228"), "94.99.101.228")
      test_good_value(IPAddr.new("94.99.0.0/16"), "94.99.0.0/16")
      test_good_value(IPAddr.new("fc00::/7"), "fc00::/7")
    end

    it "translates * characters" do
      test_good_value("123.*.*.*",     "123.0.0.0/8")
      test_good_value("123.12.*.*",    "123.12.0.0/16")
      test_good_value("123.12.1.*",    "123.12.1.0/24")
      test_good_value("123.12.*.*/16", "123.12.0.0/16")
      test_good_value("123.12.*",      "123.12.0.0/16")
      test_good_value("123.*",         "123.0.0.0/8")
    end

    it "handles bad input" do
      test_bad_value(nil)
      test_bad_value("123.123")
      test_bad_value("my house")
      test_bad_value("123.*.1.12")
      test_bad_value("*.123.*.12")
      test_bad_value("*.*.*.12")
      test_bad_value("123.*.1.12/8")
    end
  end

  describe '#watch' do
    context 'ip_address is not being watched' do
      it 'should create a new record' do
        record = described_class.watch(ip_address)
        expect(record).not_to be_new_record
        expect(record.action_type).to eq(described_class.actions[:block])
      end

      it 'lets action_type be overridden' do
        record = described_class.watch(ip_address, action_type: described_class.actions[:do_nothing])
        expect(record).not_to be_new_record
        expect(record.action_type).to eq(described_class.actions[:do_nothing])
      end

      it "a record with subnet mask exists, but doesn't match" do
        existing = Fabricate(:screened_ip_address, ip_address: '99.232.23.124/24')
        expect { described_class.watch('99.232.55.124') }.to change { described_class.count }
      end

      it "a record with exact matching exists, but doesn't match" do
        existing = Fabricate(:screened_ip_address, ip_address: '99.232.23.124')
        expect { described_class.watch('99.232.23.123') }.to change { described_class.count }
      end
    end

    context 'ip_address is already being watched' do
      shared_examples 'exact match of ip address' do
        it 'should not create a new record' do
          expect { described_class.watch(ip_address_arg) }.to_not change { described_class.count }
        end

        it 'returns the existing record' do
          expect(described_class.watch(ip_address_arg)).to eq(existing)
        end
      end

      context 'using exact match' do
        fab!(:existing) { Fabricate(:screened_ip_address) }
        let(:ip_address_arg) { existing.ip_address }
        include_examples 'exact match of ip address'
      end

      context 'using subnet mask 255.255.255.0' do
        fab!(:existing) { Fabricate(:screened_ip_address, ip_address: '99.232.23.124/24') }

        context 'at exact address' do
          let(:ip_address_arg) { '99.232.23.124' }
          include_examples 'exact match of ip address'
        end

        context 'at address in same subnet' do
          let(:ip_address_arg) { '99.232.23.135' }
          include_examples 'exact match of ip address'
        end
      end
    end

    it "doesn't block 10.0.0.0/8" do
      expect(described_class.watch('10.0.0.0').action_type).to eq(described_class.actions[:do_nothing])
      expect(described_class.watch('10.0.0.1').action_type).to eq(described_class.actions[:do_nothing])
      expect(described_class.watch('10.10.125.111').action_type).to eq(described_class.actions[:do_nothing])
    end

    it "doesn't block 192.168.0.0/16" do
      expect(described_class.watch('192.168.0.5').action_type).to eq(described_class.actions[:do_nothing])
      expect(described_class.watch('192.168.10.1').action_type).to eq(described_class.actions[:do_nothing])
    end

    it "doesn't block 127.0.0.0/8" do
      expect(described_class.watch('127.0.0.1').action_type).to eq(described_class.actions[:do_nothing])
    end

    it "doesn't block fc00::/7 addresses (IPv6)" do
      expect(described_class.watch('fd12:db8::ff00:42:8329').action_type).to eq(described_class.actions[:do_nothing])
    end
  end

  describe '#should_block?' do
    it 'returns false when record does not exist' do
      expect(described_class.should_block?(ip_address)).to eq(false)
    end

    it 'returns false when no record matches' do
      Fabricate(:screened_ip_address, ip_address: '111.234.23.11', action_type: described_class.actions[:block])
      expect(described_class.should_block?('222.12.12.12')).to eq(false)
    end

    it 'returns false if a more specific recrord matches and action is :do_nothing' do
      Fabricate(:screened_ip_address, ip_address: '111.234.23.0/24', action_type: described_class.actions[:block])
      Fabricate(:screened_ip_address, ip_address: '111.234.23.11', action_type: described_class.actions[:do_nothing])
      expect(described_class.should_block?('111.234.23.11')).to eq(false)
      expect(described_class.should_block?('111.234.23.12')).to eq(true)

      Fabricate(:screened_ip_address, ip_address: '222.234.23.0/24', action_type: described_class.actions[:do_nothing])
      Fabricate(:screened_ip_address, ip_address: '222.234.23.11', action_type: described_class.actions[:block])
      expect(described_class.should_block?('222.234.23.11')).to eq(true)
      expect(described_class.should_block?('222.234.23.12')).to eq(false)
    end

    context 'IPv4' do
      it 'returns false when when record matches and action is :do_nothing' do
        Fabricate(:screened_ip_address, ip_address: '111.234.23.11', action_type: described_class.actions[:do_nothing])
        expect(described_class.should_block?('111.234.23.11')).to eq(false)
      end

      it 'returns true when when record matches and action is :block' do
        Fabricate(:screened_ip_address, ip_address: '111.234.23.11', action_type: described_class.actions[:block])
        expect(described_class.should_block?('111.234.23.11')).to eq(true)
      end
    end

    context 'IPv6' do
      it 'returns false when when record matches and action is :do_nothing' do
        Fabricate(:screened_ip_address, ip_address: '2001:db8::ff00:42:8329', action_type: described_class.actions[:do_nothing])
        expect(described_class.should_block?('2001:db8::ff00:42:8329')).to eq(false)
      end

      it 'returns true when when record matches and action is :block' do
        Fabricate(:screened_ip_address, ip_address: '2001:db8::ff00:42:8329', action_type: described_class.actions[:block])
        expect(described_class.should_block?('2001:db8::ff00:42:8329')).to eq(true)
      end
    end
  end

  describe '#is_allowed?' do
    it 'returns false when record does not exist' do
      expect(described_class.is_allowed?(ip_address)).to eq(false)
    end

    it 'returns false when no record matches' do
      Fabricate(:screened_ip_address, ip_address: '111.234.23.11', action_type: described_class.actions[:do_nothing])
      expect(described_class.is_allowed?('222.12.12.12')).to eq(false)
    end

    context 'IPv4' do
      it 'returns true when when record matches and action is :do_nothing' do
        Fabricate(:screened_ip_address, ip_address: '111.234.23.11', action_type: described_class.actions[:do_nothing])
        expect(described_class.is_allowed?('111.234.23.11')).to eq(true)
      end

      it 'returns false when when record matches and action is :block' do
        Fabricate(:screened_ip_address, ip_address: '111.234.23.11', action_type: described_class.actions[:block])
        expect(described_class.is_allowed?('111.234.23.11')).to eq(false)
      end
    end

    context 'IPv6' do
      it 'returns true when when record matches and action is :do_nothing' do
        Fabricate(:screened_ip_address, ip_address: '2001:db8::ff00:42:8329', action_type: described_class.actions[:do_nothing])
        expect(described_class.is_allowed?('2001:db8::ff00:42:8329')).to eq(true)
      end

      it 'returns false when when record matches and action is :block' do
        Fabricate(:screened_ip_address, ip_address: '2001:db8::ff00:42:8329', action_type: described_class.actions[:block])
        expect(described_class.is_allowed?('2001:db8::ff00:42:8329')).to eq(false)
      end
    end
  end

  describe '#block_admin_login?' do
    context 'no allow_admin records exist' do

      it "returns false when use_admin_ip_allowlist is false" do
        expect(described_class.block_admin_login?(Fabricate.build(:user), '123.12.12.12')).to eq(false)
      end

      context "use_admin_ip_allowlist is true" do
        before { SiteSetting.use_admin_ip_allowlist = true }

        it "returns false when user is nil" do
          expect(described_class.block_admin_login?(nil, '123.12.12.12')).to eq(false)
        end

        it "returns false for non-admin user" do
          expect(described_class.block_admin_login?(Fabricate.build(:user), '123.12.12.12')).to eq(false)
        end

        it "returns false for admin user" do
          expect(described_class.block_admin_login?(Fabricate.build(:admin), '123.12.12.12')).to eq(false)
        end

        it "returns false for admin user and ip_address arg is nil" do
          expect(described_class.block_admin_login?(Fabricate.build(:admin), nil)).to eq(false)
        end
      end
    end

    context 'allow_admin record exists' do
      before do
        @permitted_ip_address = '111.234.23.11'
        Fabricate(:screened_ip_address, ip_address: @permitted_ip_address, action_type: described_class.actions[:allow_admin])
      end

      it "returns false when use_admin_ip_allowlist is false" do
        expect(described_class.block_admin_login?(Fabricate.build(:admin), '123.12.12.12')).to eq(false)
      end

      context "use_admin_ip_allowlist is true" do
        before { SiteSetting.use_admin_ip_allowlist = true }

        it "returns false when user is nil" do
          expect(described_class.block_admin_login?(nil, @permitted_ip_address)).to eq(false)
        end

        it "returns false for an admin user at the allowed ip address" do
          expect(described_class.block_admin_login?(Fabricate.build(:admin), @permitted_ip_address)).to eq(false)
        end

        it "returns true for an admin user at another ip address" do
          expect(described_class.block_admin_login?(Fabricate.build(:admin), '123.12.12.12')).to eq(true)
        end

        it "returns false for regular user at allowed ip address" do
          expect(described_class.block_admin_login?(Fabricate.build(:user), @permitted_ip_address)).to eq(false)
        end

        it "returns false for regular user at another ip address" do
          expect(described_class.block_admin_login?(Fabricate.build(:user), '123.12.12.12')).to eq(false)
        end
      end
    end
  end
end
