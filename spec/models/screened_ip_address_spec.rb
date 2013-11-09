require 'spec_helper'

describe ScreenedIpAddress do
  let(:ip_address) { '99.232.23.124' }
  let(:valid_params) { {ip_address: ip_address} }

  describe 'new record' do
    it 'sets a default action_type' do
      described_class.create(valid_params).action_type.should == described_class.actions[:block]
    end

    it 'sets an error when ip_address is invalid' do
      described_class.create(valid_params.merge(ip_address: '99.99.99')).errors[:ip_address].should be_present
    end

    it 'can set action_type using the action_name virtual attribute' do
      described_class.new(valid_params.merge(action_name: :do_nothing)).action_type.should == described_class.actions[:do_nothing]
      described_class.new(valid_params.merge(action_name: :block)).action_type.should == described_class.actions[:block]
      described_class.new(valid_params.merge(action_name: 'do_nothing')).action_type.should == described_class.actions[:do_nothing]
      described_class.new(valid_params.merge(action_name: 'block')).action_type.should == described_class.actions[:block]
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
  end

  describe '#watch' do
    context 'ip_address is not being watched' do
      it 'should create a new record' do
        record = described_class.watch(ip_address)
        record.should_not be_new_record
        record.action_type.should == described_class.actions[:block]
      end

      it 'lets action_type be overridden' do
        record = described_class.watch(ip_address, action_type: described_class.actions[:do_nothing])
        record.should_not be_new_record
        record.action_type.should == described_class.actions[:do_nothing]
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
          described_class.watch(ip_address_arg).should == existing
        end
      end

      context 'using exact match' do
        let!(:existing) { Fabricate(:screened_ip_address) }
        let(:ip_address_arg) { existing.ip_address }
        include_examples 'exact match of ip address'
      end

      context 'using subnet mask 255.255.255.0' do
        let!(:existing) { Fabricate(:screened_ip_address, ip_address: '99.232.23.124/24') }

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
      described_class.watch('10.0.0.0').action_type.should == described_class.actions[:do_nothing]
      described_class.watch('10.0.0.1').action_type.should == described_class.actions[:do_nothing]
      described_class.watch('10.10.125.111').action_type.should == described_class.actions[:do_nothing]
    end

    it "doesn't block 192.168.0.0/16" do
      described_class.watch('192.168.0.5').action_type.should == described_class.actions[:do_nothing]
      described_class.watch('192.168.10.1').action_type.should == described_class.actions[:do_nothing]
    end

    it "doesn't block 127.0.0.0/8" do
      described_class.watch('127.0.0.1').action_type.should == described_class.actions[:do_nothing]
    end

    it "doesn't block fc00::/7 addresses (IPv6)" do
      described_class.watch('fd12:db8::ff00:42:8329').action_type.should == described_class.actions[:do_nothing]
    end


  end

  describe '#should_block?' do
    it 'returns false when record does not exist' do
      described_class.should_block?(ip_address).should eq(false)
    end

    it 'returns false when no record matches' do
      Fabricate(:screened_ip_address, ip_address: '111.234.23.11', action_type: described_class.actions[:block])
      described_class.should_block?('222.12.12.12').should eq(false)
    end

    context 'IPv4' do
      it 'returns false when when record matches and action is :do_nothing' do
        Fabricate(:screened_ip_address, ip_address: '111.234.23.11', action_type: described_class.actions[:do_nothing])
        described_class.should_block?('111.234.23.11').should eq(false)
      end

      it 'returns true when when record matches and action is :block' do
        Fabricate(:screened_ip_address, ip_address: '111.234.23.11', action_type: described_class.actions[:block])
        described_class.should_block?('111.234.23.11').should eq(true)
      end
    end

    context 'IPv6' do
      it 'returns false when when record matches and action is :do_nothing' do
        Fabricate(:screened_ip_address, ip_address: '2001:db8::ff00:42:8329', action_type: described_class.actions[:do_nothing])
        described_class.should_block?('2001:db8::ff00:42:8329').should eq(false)
      end

      it 'returns true when when record matches and action is :block' do
        Fabricate(:screened_ip_address, ip_address: '2001:db8::ff00:42:8329', action_type: described_class.actions[:block])
        described_class.should_block?('2001:db8::ff00:42:8329').should eq(true)
      end
    end
  end

  describe '#is_whitelisted?' do
    it 'returns false when record does not exist' do
      described_class.is_whitelisted?(ip_address).should eq(false)
    end

    it 'returns false when no record matches' do
      Fabricate(:screened_ip_address, ip_address: '111.234.23.11', action_type: described_class.actions[:do_nothing])
      described_class.is_whitelisted?('222.12.12.12').should eq(false)
    end

    context 'IPv4' do
      it 'returns true when when record matches and action is :do_nothing' do
        Fabricate(:screened_ip_address, ip_address: '111.234.23.11', action_type: described_class.actions[:do_nothing])
        described_class.is_whitelisted?('111.234.23.11').should eq(true)
      end

      it 'returns false when when record matches and action is :block' do
        Fabricate(:screened_ip_address, ip_address: '111.234.23.11', action_type: described_class.actions[:block])
        described_class.is_whitelisted?('111.234.23.11').should eq(false)
      end
    end

    context 'IPv6' do
      it 'returns true when when record matches and action is :do_nothing' do
        Fabricate(:screened_ip_address, ip_address: '2001:db8::ff00:42:8329', action_type: described_class.actions[:do_nothing])
        described_class.is_whitelisted?('2001:db8::ff00:42:8329').should eq(true)
      end

      it 'returns false when when record matches and action is :block' do
        Fabricate(:screened_ip_address, ip_address: '2001:db8::ff00:42:8329', action_type: described_class.actions[:block])
        described_class.is_whitelisted?('2001:db8::ff00:42:8329').should eq(false)
      end
    end
  end
end
