# frozen_string_literal: true

class CreateSiteTrafficDataLayer < ActiveRecord::Migration[8.0]
  EVENT_TABLES = %i[browser_pageview_events browser_pageview_events_beacon]

  def up
    EVENT_TABLES.each { |table_name| create_event_table(table_name) }

    create_table :pageview_daily_aggregates, id: false do |t|
      t.date :date, null: false
      t.string :country_code, limit: 2
      t.string :source_name, limit: 100, null: false
      t.boolean :is_logged_in, null: false
      t.integer :count, null: false
    end

    execute <<~SQL
      ALTER TABLE pageview_daily_aggregates
      ADD PRIMARY KEY (date, country_code, source_name, is_logged_in)
    SQL

    execute <<~SQL
      CREATE VIEW browser_pageview_events_combined AS
        SELECT
          id,
          created_at,
          url,
          ip_address,
          referrer,
          user_agent,
          session_id,
          country_code,
          user_id,
          topic_id,
          false AS is_beacon
        FROM browser_pageview_events
        UNION ALL
        SELECT
          id,
          created_at,
          url,
          ip_address,
          referrer,
          user_agent,
          session_id,
          country_code,
          user_id,
          topic_id,
          true AS is_beacon
        FROM browser_pageview_events_beacon
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS browser_pageview_events_combined"
    drop_table :pageview_daily_aggregates
    EVENT_TABLES.each { |table_name| drop_table table_name }
  end

  private

  def create_event_table(table_name)
    create_table table_name do |t|
      t.datetime :created_at, null: false
      t.string :url, limit: 2000, null: false
      t.inet :ip_address
      t.string :referrer, limit: 2000
      t.string :user_agent, limit: 1000, null: false
      t.string :session_id, limit: 32, null: false
      t.string :country_code, limit: 2
      t.integer :user_id
      t.integer :topic_id
    end

    add_index table_name, :created_at, using: :brin
    add_index table_name, :user_id
    add_index table_name, :topic_id
  end
end
