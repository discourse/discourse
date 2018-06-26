require 'rails_helper'
require_dependency 'active_record/connection_adapters/postgresql_fallback_adapter'

describe ActiveRecord::ConnectionHandling do
  let(:replica_host) { "1.1.1.1" }
  let(:replica_port) { 6432 }

  let(:config) do
    ActiveRecord::Base.connection_config.merge(
      adapter: "postgresql_fallback",
      replica_host: replica_host,
      replica_port: replica_port
    )
  end

  let(:multisite_db) { "database_2" }

  let(:multisite_config) do
    {
      host: 'localhost1',
      port: 5432,
      replica_host: replica_host,
      replica_port: replica_port
    }
  end

  let(:postgresql_fallback_handler) { PostgreSQLFallbackHandler.instance }

  before do
    postgresql_fallback_handler.initialized = true

    ['default', multisite_db].each do |db|
      postgresql_fallback_handler.master_up(db)
    end
  end

  after do
    postgresql_fallback_handler.setup!
    Discourse.disable_readonly_mode(Discourse::PG_READONLY_MODE_KEY)
    ActiveRecord::Base.unstub(:postgresql_connection)
    ActiveRecord::Base.establish_connection
  end

  describe "#postgresql_fallback_connection" do
    it 'should return a PostgreSQL adapter' do
      begin
        connection = ActiveRecord::Base.postgresql_fallback_connection(config)

        expect(connection)
          .to be_an_instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
      ensure
        connection.disconnect!
      end
    end

    context 'when master server is down' do
      before do
        @replica_connection = mock('replica_connection')
      end

      after do
        pg_readonly_mode_key = Discourse::PG_READONLY_MODE_KEY

        with_multisite_db(multisite_db) do
          Discourse.disable_readonly_mode(pg_readonly_mode_key)
        end

        Discourse.disable_readonly_mode(pg_readonly_mode_key)
        ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[Rails.env])
      end

      it 'should failover to a replica server' do
        # erratically fails with: ActiveRecord::ConnectionTimeoutError:
        # could not obtain a connection from the pool within 5.000 seconds (waited 5.000 seconds); all pooled connections were in use
        #
        skip("This test is failing erratically")

        RailsMultisite::ConnectionManagement.stubs(:all_dbs).returns(['default', multisite_db])
        postgresql_fallback_handler.expects(:verify_master).at_least(3)

        [config, multisite_config].each do |configuration|
          ActiveRecord::Base.expects(:postgresql_connection).with(configuration).raises(PG::ConnectionBad)
          ActiveRecord::Base.expects(:verify_replica).with(@replica_connection)

          ActiveRecord::Base.expects(:postgresql_connection).with(
            configuration.dup.merge(host: replica_host, port: replica_port)
          ).returns(@replica_connection)
        end

        expect(postgresql_fallback_handler.master_down?).to eq(nil)

        message = MessageBus.track_publish(PostgreSQLFallbackHandler::DATABASE_DOWN_CHANNEL) do
          expect { ActiveRecord::Base.postgresql_fallback_connection(config) }
            .to raise_error(PG::ConnectionBad)
        end.first

        expect(message.data[:db]).to eq('default')

        expect { ActiveRecord::Base.postgresql_fallback_connection(config) }
          .to change { Discourse.readonly_mode? }.from(false).to(true)

        expect(postgresql_fallback_handler.master_down?).to eq(true)
        expect(Sidekiq.paused?).to eq(true)

        with_multisite_db(multisite_db) do
          begin
            expect(postgresql_fallback_handler.master_down?).to eq(nil)

            message = MessageBus.track_publish(PostgreSQLFallbackHandler::DATABASE_DOWN_CHANNEL) do
              expect { ActiveRecord::Base.postgresql_fallback_connection(multisite_config) }
                .to raise_error(PG::ConnectionBad)
            end.first

            expect(message.data[:db]).to eq(multisite_db)

            expect { ActiveRecord::Base.postgresql_fallback_connection(multisite_config) }
              .to change { Discourse.readonly_mode? }.from(false).to(true)

            expect(postgresql_fallback_handler.master_down?).to eq(true)
          ensure
            postgresql_fallback_handler.master_up(multisite_db)
            expect(postgresql_fallback_handler.master_down?).to eq(nil)
          end
        end

        ActiveRecord::Base.unstub(:postgresql_connection)

        postgresql_fallback_handler.initiate_fallback_to_master

        expect(Discourse.readonly_mode?).to eq(false)
        expect(Sidekiq.paused?).to eq(false)

        # fails sometimes on this line!
        expect(ActiveRecord::Base.connection_pool.connections.count).to eq(0)
        expect(postgresql_fallback_handler.master_down?).to eq(nil)

        expect(ActiveRecord::Base.connection)
          .to be_an_instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
      end
    end

    context 'when both master and replica server is down' do
      it 'should raise the right error' do
        ActiveRecord::Base.expects(:postgresql_connection).with(config).raises(PG::ConnectionBad)

        ActiveRecord::Base.expects(:postgresql_connection).with(
          config.dup.merge(host: replica_host, port: replica_port)
        ).raises(PG::ConnectionBad).once

        postgresql_fallback_handler.expects(:verify_master).twice

        2.times do
          expect { ActiveRecord::Base.postgresql_fallback_connection(config) }
            .to raise_error(PG::ConnectionBad)
        end
      end
    end
  end

  describe '.verify_replica' do
    describe 'when database is not in recovery' do
      it 'should raise the right error' do
        expect do
          ActiveRecord::Base.send(:verify_replica, ActiveRecord::Base.connection)
        end.to raise_error(RuntimeError, "Replica database server is not in recovery mode.")
      end
    end
  end

  def with_multisite_db(dbname)
    RailsMultisite::ConnectionManagement.expects(:current_db).returns(dbname).at_least_once
    yield
    RailsMultisite::ConnectionManagement.unstub(:current_db)
  end
end
