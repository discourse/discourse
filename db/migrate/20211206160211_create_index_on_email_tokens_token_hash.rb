# frozen_string_literal: true

class CreateIndexOnEmailTokensTokenHash < ActiveRecord::Migration[6.1]
  def change
    add_index :email_tokens, :token_hash, unique: true
  end
end
