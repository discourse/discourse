# frozen_string_literal: true

class CreateAiMcpOauthTokens < ActiveRecord::Migration[8.0]
  def up
    create_table :ai_mcp_oauth_tokens do |t|
      t.bigint :ai_mcp_server_id, null: false
      t.text :access_token
      t.text :refresh_token

      t.timestamps
    end

    add_index :ai_mcp_oauth_tokens, :ai_mcp_server_id, unique: true
  end

  def down
    drop_table :ai_mcp_oauth_tokens
  end
end
