# frozen_string_literal: true
class CreateUserApiKeyClientScopes < ActiveRecord::Migration[7.1]
  def change
    create_table :user_api_key_client_scopes do |t|
      t.bigint :user_api_key_client_id, null: false
      t.string :name, null: false, limit: 100
      t.timestamps
    end
  end
end
