# frozen_string_literal: true

class AddUserAuthTokens < ActiveRecord::Migration[4.2]
  def down
    execute <<SQL
      UPDATE users
        SET auth_token = user_auth_tokens.auth_token,
            auth_token_updated_at = user_auth_tokens.created_at
      FROM user_auth_tokens
      WHERE legacy AND user_auth_tokens.user_id = users.id
SQL

    drop_table :user_auth_tokens

  end

  def up
    create_table :user_auth_tokens do |t|
      t.integer :user_id, null: false
      t.string  :auth_token, null: false
      t.string  :prev_auth_token, null: false
      t.string  :user_agent
      t.boolean :auth_token_seen, default: false, null: false
      t.boolean :legacy, default: false, null: false
      t.inet    :client_ip
      t.datetime :rotated_at, null: false
      t.timestamps null: false
    end

    add_index :user_auth_tokens, [:auth_token]
    add_index :user_auth_tokens, [:prev_auth_token]

    execute <<~SQL
    INSERT INTO user_auth_tokens(user_id, auth_token, prev_auth_token, legacy, updated_at, created_at, rotated_at)
    SELECT id, auth_token, auth_token, true, auth_token_updated_at, auth_token_updated_at, auth_token_updated_at
    FROM users
    WHERE auth_token_updated_at IS NOT NULL AND auth_token IS NOT NULL
    SQL
  end
end
