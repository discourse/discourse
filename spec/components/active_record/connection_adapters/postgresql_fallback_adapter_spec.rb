require 'rails_helper'
require_dependency 'active_record/connection_adapters/postgresql_fallback_adapter'

describe ActiveRecord::ConnectionHandling do
  let(:replica_host) { "1.1.1.1" }
  let(:replica_port) { 6432 }

  let(:config) do
    ActiveRecord::Base.configurations[Rails.env].merge({
      "adapter" => "postgresql_fallback",
      "replica_host" => replica_host,
      "replica_port" => replica_port
    }).symbolize_keys!
  end

  let(:postgresql_fallback_handler) { PostgreSQLFallbackHandler.instance }

  after do
    postgresql_fallback_handler.setup!
  end

  describe "#postgresql_fallback_connection" do
    it 'should return a PostgreSQL adapter' do
      expect(ActiveRecord::Base.postgresql_fallback_connection(config))
        .to be_an_instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    end

    context 'when master server is down' do
      let(:multisite_db) { "database_2" }

      let(:multisite_config) do
        {
          host: 'localhost1',
          port: 5432,
          replica_host: replica_host,
          replica_port: replica_port
        }
      end

      before do
        @replica_connection = mock('replica_connection')
      end

      after do
        with_multisite_db(multisite_db) { Discourse.disable_readonly_mode }
        Discourse.disable_readonly_mode
        ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[Rails.env])
      end

      it 'should failover to a replica server' do
        RailsMultisite::ConnectionManagement.stubs(:all_dbs).returns(['default', multisite_db])
        ::PostgreSQLFallbackHandler.instance.setup!

        [config, multisite_config].each do |configuration|
          ActiveRecord::Base.expects(:postgresql_connection).with(configuration).raises(PG::ConnectionBad)
          ActiveRecord::Base.expects(:verify_replica).with(@replica_connection)

          ActiveRecord::Base.expects(:postgresql_connection).with(configuration.merge({
            host: replica_host, port: replica_port
          })).returns(@replica_connection)
        end

        expect(postgresql_fallback_handler.master).to eq(true)

        expect { ActiveRecord::Base.postgresql_fallback_connection(config) }
          .to raise_error(PG::ConnectionBad)

        expect{ ActiveRecord::Base.postgresql_fallback_connection(config) }
          .to change{ Discourse.readonly_mode? }.from(false).to(true)

        expect(postgresql_fallback_handler.master).to eq(false)

        with_multisite_db(multisite_db) do
          expect(postgresql_fallback_handler.master).to eq(true)

          expect { ActiveRecord::Base.postgresql_fallback_connection(multisite_config) }
            .to raise_error(PG::ConnectionBad)

          expect{ ActiveRecord::Base.postgresql_fallback_connection(multisite_config) }
            .to change{ Discourse.readonly_mode? }.from(false).to(true)

          expect(postgresql_fallback_handler.master).to eq(false)
        end

        ActiveRecord::Base.unstub(:postgresql_connection)

        current_threads = Thread.list

        expect{ ActiveRecord::Base.connection_pool.checkout }
          .to change{ Thread.list.size }.by(1)

        # Ensure that we don't try to connect back to the replica when a thread
        # is running
        begin
          ActiveRecord::Base.postgresql_fallback_connection(config)
        rescue PG::ConnectionBad => e
          # This is expected if the thread finishes before the above is called.
        end

        # Wait for the thread to finish execution
        (Thread.list - current_threads).each(&:join)

        expect(Discourse.readonly_mode?).to eq(false)

        expect(PostgreSQLFallbackHandler.instance.master).to eq(true)

        expect(ActiveRecord::Base.connection_pool.connections.count).to eq(0)

        expect(ActiveRecord::Base.connection)
          .to be_an_instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
      end
    end

    context 'when both master and replica server is down' do
      it 'should raise the right error' do
        ActiveRecord::Base.expects(:postgresql_connection).with(config).raises(PG::ConnectionBad).once

        ActiveRecord::Base.expects(:postgresql_connection).with(config.dup.merge({
          host: replica_host, port: replica_port
        })).raises(PG::ConnectionBad).once

        2.times do
          expect { ActiveRecord::Base.postgresql_fallback_connection(config) }
            .to raise_error(PG::ConnectionBad)
        end
      end
    end
  end

  def with_multisite_db(dbname)
    RailsMultisite::ConnectionManagement.expects(:current_db).returns(dbname).at_least_once
    yield
    RailsMultisite::ConnectionManagement.unstub(:current_db)
  end
end
