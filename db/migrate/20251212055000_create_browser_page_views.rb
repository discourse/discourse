# frozen_string_literal: true

class CreateBrowserPageViews < ActiveRecord::Migration[7.2]
  def change
    create_table :browser_page_views, id: false do |t|
      t.string :session_id, limit: 36
      t.integer :user_id
      t.integer :topic_id
      t.string :path, limit: 1024
      t.string :query_string, limit: 1024
      t.string :route_name, limit: 256
      t.string :referrer, limit: 1024
      t.string :previous_path, limit: 1024
      t.inet :ip_address
      t.string :user_agent, limit: 512
      t.boolean :is_mobile, default: false, null: false
      t.datetime :created_at, null: false
    end

    add_index :browser_page_views, :session_id
    add_index :browser_page_views, :user_id
    add_index :browser_page_views, :topic_id
    add_index :browser_page_views, :route_name
    add_index :browser_page_views, :created_at
  end
end
