# frozen_string_literal: true
class CreateUserApiKeyClients < ActiveRecord::Migration[7.1]
  def up
    create_table :user_api_key_clients do |t|
      t.string :client_id, null: false
      t.string :application_name, null: false
      t.string :public_key
      t.string :auth_redirect

      t.timestamps
    end

    add_index :user_api_key_clients, %i[client_id], unique: true

    execute "INSERT INTO user_api_key_clients (client_id, application_name, created_at, updated_at)
             SELECT client_id, application_name, created_at, updated_at
             FROM user_api_keys"

    add_column :user_api_keys, :user_api_key_client_id, :bigint, null: true
    add_index :user_api_keys, :user_api_key_client_id

    execute "UPDATE user_api_keys keys
             SET user_api_key_client_id = clients.id
             FROM user_api_key_clients clients
             WHERE clients.client_id = keys.client_id"

    change_column_null :user_api_keys, :client_id, true
    change_column_null :user_api_keys, :application_name, true
  end

  def down
    execute "UPDATE user_api_keys keys
             SET client_id = clients.client_id,
                 application_name = clients.application_name
             FROM user_api_key_clients clients
             WHERE clients.id = keys.user_api_key_client_id"

    remove_column :user_api_keys, :user_api_key_client_id
    change_column_null :user_api_keys, :client_id, false
    change_column_null :user_api_keys, :application_name, false

    remove_index :user_api_key_clients, :client_id
    drop_table :user_api_key_clients
  end
end
