# frozen_string_literal: true

RSpec.describe "Caching PostgreSQL connection type map" do
  it "caches the type map and avoid querying the database for type map information on every new connection" do
    expect(ActiveRecord::Base.connection.class.type_map).to be_present

    pg_type_queries = []

    subscriber =
      ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        if payload[:name] == "SCHEMA"
          sql = payload[:sql]
          pg_type_queries.push(sql) if sql.include?("pg_type")
        end
      end

    expect do
      ActiveRecord::Base.clear_active_connections!
      ActiveRecord::Base.establish_connection
    end.to change { pg_type_queries.length }.by(1) # There is some default pg_type query but if stuff was not cached, we would see 4 queries here
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
