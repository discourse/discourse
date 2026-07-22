# frozen_string_literal: true

require "tempfile"

RSpec.describe AdminDashboardSearch, type: :multisite do
  self.use_transactional_tests = false

  def async_sql_events
    events = []
    subscriber =
      ActiveSupport::Notifications.subscribe(
        "sql.active_record",
      ) do |_name, _start, _finish, _id, payload|
        if payload[:async]
          events << {
            database: payload[:connection]&.pool&.db_config&.database,
            sql: payload[:sql],
          }
        end
      end

    yield events
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def with_multisite_config(configs)
    file = Tempfile.new(%w[admin-dashboard-async-multisite .yml])
    file.write(configs.to_yaml)
    file.close

    RailsMultisite::ConnectionManagement.config_filename = file.path
    RailsMultisite::ConnectionManagement.establish_connection(db: "default")
    yield
  ensure
    RailsMultisite::ConnectionManagement.config_filename = "spec/fixtures/multisite/two_dbs.yml"
    RailsMultisite::ConnectionManagement.establish_connection(db: "default")
    file&.unlink
  end

  def site_config(database:, pool:, max_threads: nil, host_name: nil)
    config = {
      "adapter" => "postgresql",
      "database" => database,
      "host_names" => [host_name || "#{database}.localhost"],
      "pool" => pool,
    }
    config["max_threads"] = max_threads if !max_threads.nil?
    config
  end

  def current_multisite_databases
    databases = { "default" => ActiveRecord::Base.connection_db_config.database }
    RailsMultisite::ConnectionManagement.instance.db_spec_cache.each do |site, specification|
      databases[site] = specification.to_hash.fetch(:database)
    end
    databases
  end

  it "reserves caller capacity for resolved multisite configurations" do
    databases = current_multisite_databases
    configs = {
      "pool_one" => site_config(database: databases.fetch("default"), pool: 1),
      "pool_two" => site_config(database: databases.fetch("default"), pool: 2),
      "pool_five" => site_config(database: databases.fetch("second"), pool: 5),
      "pool_eight" => site_config(database: databases.fetch("second"), pool: 8, max_threads: 99),
      "explicit_lower" =>
        site_config(database: databases.fetch("default"), pool: 8, max_threads: 3),
    }

    with_multisite_config(configs) do
      resolved_threads =
        RailsMultisite::ConnectionManagement
          .instance
          .db_spec_cache
          .transform_values { |specification| specification.to_hash.fetch(:max_threads) }

      expect(resolved_threads).to include(
        "pool_one" => 0,
        "pool_two" => 1,
        "pool_five" => 4,
        "pool_eight" => 7,
        "explicit_lower" => 3,
      )
    end
  end

  it "preserves multisite context for concurrent async query execution" do
    results = Queue.new
    databases = current_multisite_databases
    configs = {
      "first" =>
        site_config(database: databases.fetch("default"), pool: 3, host_name: "test.localhost"),
      "second" =>
        site_config(database: databases.fetch("second"), pool: 3, host_name: "test2.localhost"),
    }

    with_multisite_config(configs) do
      async_sql_events do |events|
        threads =
          %w[first second].map do |site|
            Thread.new do
              RailsMultisite::ConnectionManagement.establish_connection(db: site)
              ActiveSupport::Executor.wrap do
                executor = ActiveRecord::Base.connection_pool.async_executor
                database = ActiveRecord::Base.connection_db_config.database
                rows =
                  ActiveRecord::Base
                    .connection
                    .select_all(
                      "SELECT current_database() AS database /* multisite-async-#{site} */",
                      "SQL",
                      [],
                      async: true,
                    )
                    .then(&:to_a)
                    .value
                ordinary = ActiveRecord::Base.connection.select_value("SELECT 1")

                begin
                  ActiveRecord::Base
                    .connection
                    .select_all(
                      "SELECT invalid_column /* multisite-failure-#{site} */",
                      "SQL",
                      [],
                      async: true,
                    )
                    .then(&:to_a)
                    .value
                rescue ActiveRecord::StatementInvalid
                end

                results << [
                  site,
                  database,
                  executor.max_length,
                  rows.first.fetch("database"),
                  ordinary,
                ]
              end
            end
          end
        threads.each(&:join)

        rows = 2.times.map { results.pop }
        expect(rows.map(&:first)).to contain_exactly("first", "second")
        rows.each do |site, expected_database, max_length, actual_database, ordinary|
          expect(max_length).to eq(2)
          expect(actual_database).to eq(expected_database)
          expect(ordinary).to eq(1)
          expect(
            events.any? do |event|
              event[:database] == expected_database &&
                event[:sql].include?("multisite-async-#{site}")
            end,
          ).to eq(true)
        end
        expect(
          rows
            .map do |_site, _expected_database, _max_length, actual_database, _ordinary|
              actual_database
            end
            .uniq
            .size,
        ).to eq(2)
      end
    end

    RailsMultisite::ConnectionManagement.with_connection("second") do
      expect(ActiveRecord::Base.connection.select_value("SELECT 1")).to eq(1)
    end
  end
end
