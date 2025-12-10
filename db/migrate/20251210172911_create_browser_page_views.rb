# frozen_string_literal: true

class CreateBrowserPageViews < ActiveRecord::Migration[7.2]
  def change
    create_table :browser_page_views, id: false do |t|
      t.integer :user_id
      t.integer :topic_id
      t.string :path, limit: 1024
      t.string :query_string, limit: 1024
      t.string :route, limit: 100
      t.string :user_agent, limit: 512
      t.inet :ip_address
      t.string :referrer, limit: 1024
      t.boolean :is_crawler, default: false, null: false
      t.boolean :is_mobile, default: false, null: false
      t.boolean :is_api, default: false, null: false
      t.boolean :is_user_api, default: false, null: false
      t.integer :http_status
      t.datetime :created_at, null: false
    end

    add_index :browser_page_views, :user_id
    add_index :browser_page_views, :topic_id
    add_index :browser_page_views, :created_at
    add_index :browser_page_views, :ip_address
  end
end
