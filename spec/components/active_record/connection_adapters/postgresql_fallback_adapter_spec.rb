require 'rails_helper'
require_dependency 'active_record/connection_adapters/postgresql_fallback_adapter'

describe ActiveRecord::ConnectionAdapters::PostgreSQLFallbackAdapter do
  let(:master_connection) { ActiveRecord::Base.connection }
  let(:replica_connection) { master_connection.dup }
  let(:adapter) { described_class.new(master_connection, replica_connection, nil, nil) }

  before :each do
    ActiveRecord::Base.clear_all_connections!
  end

  describe "proxy_method" do
    context "when master connection is not active" do
      before do
        replica_connection.stubs(:send)
        master_connection.stubs(:send).raises(ActiveRecord::StatementInvalid.new('PG::UnableToSend'))
        master_connection.stubs(:reconnect!)
        master_connection.stubs(:active?).returns(false)

        @old_const = described_class::HEARTBEAT_INTERVAL
        described_class.const_set("HEARTBEAT_INTERVAL", 0.1)
      end

      after do
        Discourse.disable_readonly_mode
        described_class.const_set("HEARTBEAT_INTERVAL", @old_const)
      end

      it "should set site to readonly mode and carry out failover and switch back procedures" do
        expect(adapter.main_connection).to eq(master_connection)
        adapter.proxy_method('some method')
        expect(Discourse.readonly_mode?).to eq(true)
        expect(adapter.main_connection).to eq(replica_connection)

        master_connection.stubs(:active?).returns(true)
        sleep 0.15

        expect(Discourse.readonly_mode?).to eq(false)
        expect(adapter.main_connection).to eq(master_connection)
      end
    end

    it 'should raise errors not related to the database connection' do
      master_connection.stubs(:send).raises(StandardError.new)
      expect { adapter.proxy_method('some method') }.to raise_error(StandardError)
    end

    it 'should proxy methods successfully' do
      expect(adapter.proxy_method(:execute, 'SELECT 1').values[0][0]).to eq("1")
      expect(adapter.proxy_method(:active?)).to eq(true)
      expect(adapter.proxy_method(:raw_connection)).to eq(master_connection.raw_connection)
    end
  end
end
