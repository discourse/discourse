# frozen_string_literal: true

class AddUserAuthTokenLog < ActiveRecord::Migration[4.2]
  def change
    create_table :user_auth_token_logs do |t|
      t.string :action, null: false
      t.integer :user_auth_token_id
      t.integer :user_id
      t.inet :client_ip
      t.string :user_agent
      t.string :auth_token
      t.datetime :created_at
    end
  end
end
