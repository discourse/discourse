# frozen_string_literal: true

require 'rails_helper'

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
    @threads = Thread.list
    postgresql_fallback_handler.initialized = true
  end

  after do
    Sidekiq.unpause!
    (Thread.list - @threads).each(&:kill)
    postgresql_fallback_handler.setup!

    ActiveRecord::Base.unstub(:postgresql_connection)
    ActiveRecord::Base.clear_all_connections!
    ActiveRecord::Base.establish_connection

    Discourse.redis.flushall
  end

  describe "#postgresql_fallback_connection" do
    it 'should return a PostgreSQL adapter' do
      connection = ActiveRecord::Base.postgresql_fallback_connection(config)

      expect(connection)
        .to be_an_instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    end

    context 'when master server is down' do
      let(:replica_connection) { mock('replica_connection') }

      it 'should failover to a replica server' do
        RailsMultisite::ConnectionManagement
          .stubs(:all_dbs)
          .returns(['default', multisite_db])

        postgresql_fallback_handler.expects(:verify_master).at_least(3)

        [config, multisite_config].each do |configuration|
          ActiveRecord::Base.expects(:postgresql_connection)
            .with(configuration)
            .raises(PG::ConnectionBad)

          ActiveRecord::Base.expects(:verify_replica).with(replica_connection)

          ActiveRecord::Base.expects(:postgresql_connection).with(
            configuration.dup.merge(host: replica_host, port: replica_port)
          ).returns(replica_connection)
        end

        expect(postgresql_fallback_handler.master_down?).to eq(nil)

        message = MessageBus.track_publish(PostgreSQLFallbackHandler::DATABASE_DOWN_CHANNEL) do
          expect { ActiveRecord::Base.postgresql_fallback_connection(config) }
            .to raise_error(PG::ConnectionBad)
        end.first

        expect(message.data[:db]).to eq('default')
        expect(message.data[:pid]).to eq(Process.pid)

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

            expect do
              ActiveRecord::Base.postgresql_fallback_connection(multisite_config)
            end.to change { Discourse.readonly_mode? }.from(false).to(true)

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
        expect(ActiveRecord::Base.connection_pool.connections.count).to eq(0)
        expect(postgresql_fallback_handler.master_down?).to eq(nil)

        expect(ActiveRecord::Base.connection)
          .to be_an_instance_of(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
      end
    end

    context 'when both master and replica server is down' do
      it 'should raise the right error' do
        ActiveRecord::Base.expects(:postgresql_connection)
          .with(config)
          .raises(PG::ConnectionBad)
          .once

        ActiveRecord::Base.expects(:postgresql_connection)
          .with(
            config.dup.merge(host: replica_host, port: replica_port)
          )
          .raises(PG::ConnectionBad)
          .once

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
    begin
      RailsMultisite::ConnectionManagement.expects(:current_db).returns(dbname).at_least_once
      yield
    ensure
      RailsMultisite::ConnectionManagement.unstub(:current_db)
    end
  end
end
