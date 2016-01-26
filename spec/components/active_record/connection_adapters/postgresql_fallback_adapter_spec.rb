require 'rails_helper'
require_dependency 'active_record/connection_adapters/postgresql_fallback_adapter'

describe ActiveRecord::ConnectionHandling do
  let(:config) do
    ActiveRecord::Base.configurations["test"].merge({
      "adapter" => "postgresql_fallback",
      "replica_host" => "localhost",
      "replica_port" => "6432"
    })
  end

  after do
    ActiveRecord::Base.clear_all_connections!
    Discourse.disable_readonly_mode
  end

  describe "#postgresql_fallback_connection" do
    it 'should return a PostgreSQL adapter' do
      expect(ActiveRecord::Base.postgresql_fallback_connection(config))
        .to be_an_instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    end

    context 'when master server is down' do
      before do
        @replica_connection = mock('replica_connection')

        ActiveRecord::Base.expects(:postgresql_connection).with(config).raises(PG::ConnectionBad)

        ActiveRecord::Base.expects(:postgresql_connection).with(config.merge({
          "host" => "localhost", "port" => "6432"
        })).returns(@replica_connection)

        ActiveRecord::Base.expects(:verify_replica).with(@replica_connection)

        @replica_connection.expects(:disconnect!)

        ActiveRecord::Base.stubs(:interval).returns(0.1)

        Concurrent::TimerTask.any_instance.expects(:shutdown)
      end

      it 'should failover to a replica server' do
        ActiveRecord::Base.postgresql_fallback_connection(config)

        expect(Discourse.readonly_mode?).to eq(true)

        ActiveRecord::Base.unstub(:postgresql_connection)
        sleep 0.15

        expect(Discourse.readonly_mode?).to eq(false)

        expect(ActiveRecord::Base.connection)
          .to be_an_instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
      end
    end

    context 'when both master and replica server is down' do
      it 'should raise the right error' do
        ActiveRecord::Base.expects(:postgresql_connection).raises(PG::ConnectionBad).twice

        expect { ActiveRecord::Base.postgresql_fallback_connection(config) }
          .to raise_error(PG::ConnectionBad)
      end
    end
  end
end
