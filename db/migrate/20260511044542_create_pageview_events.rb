# frozen_string_literal: true

class CreatePageviewEvents < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:browser_pageview_events)

    create_table :browser_pageview_events do |t|
      t.string :url, null: false, limit: 2000
      t.inet :ip_address, null: false
      t.string :referrer, null: true, limit: 2000
      t.string :user_agent, null: false, limit: 1000
      t.string :session_id, null: false, limit: 32
      t.integer :topic_id, null: true
      t.integer :user_id, null: true
      t.string :country_code, null: true, limit: 2
      t.timestamp :created_at, null: false
    end

    add_index :browser_pageview_events, :created_at, using: :brin
    add_index :browser_pageview_events, :user_id
    add_index :browser_pageview_events, :topic_id
  end
end
