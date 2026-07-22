# frozen_string_literal: true

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

  it "preserves multisite context for concurrent async query execution" do
    results = Queue.new

    async_sql_events do |events|
      threads =
        %w[default second].map do |site|
          Thread.new do
            RailsMultisite::ConnectionManagement.establish_connection(db: site)
            ActiveSupport::Executor.wrap do
              configuration = ActiveRecord::Base.connection_db_config.configuration_hash
              ActiveRecord::Base.establish_connection(configuration.merge(pool: 3, max_threads: 2))
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

              results << [site, database, rows.first.fetch("database"), ordinary]
            end
          end
        end
      threads.each(&:join)

      rows = 2.times.map { results.pop }
      expect(rows.map(&:first)).to contain_exactly("default", "second")
      rows.each do |site, expected_database, actual_database, ordinary|
        expect(actual_database).to eq(expected_database)
        expect(ordinary).to eq(1)
        expect(
          events.any? do |event|
            event[:database] == expected_database && event[:sql].include?("multisite-async-#{site}")
          end,
        ).to eq(true)
      end
      expect(
        rows
          .map { |_site, _expected_database, actual_database, _ordinary| actual_database }
          .uniq
          .size,
      ).to eq(2)
    end

    RailsMultisite::ConnectionManagement.with_connection("default") do
      expect(ActiveRecord::Base.connection.select_value("SELECT 1")).to eq(1)
    end
    RailsMultisite::ConnectionManagement.with_connection("second") do
      expect(ActiveRecord::Base.connection.select_value("SELECT 1")).to eq(1)
    end
  end
end
