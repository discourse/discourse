# frozen_string_literal: true

class CreateSiteTrafficDataLayer < ActiveRecord::Migration[8.0]
  EVENT_TABLES = %i[browser_pageview_events browser_pageview_events_beacon]
  AGGREGATE_TABLES = %i[pageview_daily_aggregates pageview_daily_aggregates_beacon]

  def up
    EVENT_TABLES.each { |table_name| create_event_table(table_name) }
    AGGREGATE_TABLES.each { |table_name| create_aggregate_table(table_name) }
  end

  def down
    AGGREGATE_TABLES.each { |table_name| drop_table table_name }
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

  def create_aggregate_table(table_name)
    create_table table_name, id: false do |t|
      t.date :date, null: false
      t.string :country_code, limit: 2
      t.string :source_name, limit: 100, null: false
      t.boolean :is_logged_in, null: false
      t.integer :count, null: false
    end

    add_index table_name,
              %i[date country_code source_name is_logged_in],
              unique: true,
              name: "#{table_name}_with_country_idx",
              where: "country_code IS NOT NULL"

    add_index table_name,
              %i[date source_name is_logged_in],
              unique: true,
              name: "#{table_name}_without_country_idx",
              where: "country_code IS NULL"
  end
end
