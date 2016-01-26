require 'rails_helper'
require_dependency 'active_record/connection_adapters/postgresql_fallback_adapter'

describe ActiveRecord::ConnectionHandling do
  let(:config) do
    ActiveRecord::Base.configurations["test"].merge({
      "adapter" => "postgresql_fallback",
      "replica_host" => "localhost",
      "replica_port" => "6432"
    }).symbolize_keys!
  end

  after do
    Discourse.disable_readonly_mode
    ::PostgreSQLFallbackHandler.instance.master = true
  end

  describe "#postgresql_fallback_connection" do
    it 'should return a PostgreSQL adapter' do
      expect(ActiveRecord::Base.postgresql_fallback_connection(config))
        .to be_an_instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    end

    context 'when master server is down' do
      before do
        @replica_connection = mock('replica_connection')
      end

      it 'should failover to a replica server' do
        begin
          ActiveRecord::Base.expects(:postgresql_connection).with(config).raises(PG::ConnectionBad)
          ActiveRecord::Base.expects(:verify_replica).with(@replica_connection)

          ActiveRecord::Base.expects(:postgresql_connection).with(config.merge({
            host: "localhost", port: "6432"
          })).returns(@replica_connection)

          expect { ActiveRecord::Base.postgresql_fallback_connection(config) }
            .to raise_error(PG::ConnectionBad)

          expect{ ActiveRecord::Base.postgresql_fallback_connection(config) }
            .to change{ Discourse.readonly_mode? }.from(false).to(true)

          ActiveRecord::Base.unstub(:postgresql_connection)

          current_threads = Thread.list

          expect{ ActiveRecord::Base.connection_pool.checkout }
            .to change{ Thread.list.size }.by(1)

          # Wait for the thread to finish execution
          threads = (Thread.list - current_threads).each(&:join)

          expect(Discourse.readonly_mode?).to eq(false)

          expect(ActiveRecord::Base.connection_pool.connections.count).to eq(0)

          expect(ActiveRecord::Base.connection)
            .to be_an_instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
        ensure
          # threads.each { |t| Thread.kill(t) } if threads
          ActiveRecord::Base.establish_connection(:test)
        end
      end
    end

    context 'when both master and replica server is down' do
      it 'should raise the right error' do
        ActiveRecord::Base.expects(:postgresql_connection).raises(PG::ConnectionBad).twice

        2.times do
          expect { ActiveRecord::Base.postgresql_fallback_connection(config) }
            .to raise_error(PG::ConnectionBad)
        end
      end
    end
  end
end
