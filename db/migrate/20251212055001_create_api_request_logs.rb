# frozen_string_literal: true

class CreateApiRequestLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :api_request_logs, id: false do |t|
      t.integer :user_id
      t.string :path, limit: 1024
      t.string :route, limit: 100
      t.string :http_method, limit: 10
      t.integer :http_status
      t.inet :ip_address
      t.string :user_agent, limit: 512
      t.boolean :is_user_api, default: false, null: false
      t.float :response_time
      t.datetime :created_at, null: false
    end

    add_index :api_request_logs, :user_id
    add_index :api_request_logs, :route
    add_index :api_request_logs, :http_status
    add_index :api_request_logs, :created_at
  end
end
