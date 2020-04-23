# frozen_string_literal: true

class AddIndexToUserApiKeyOnKeyHash < ActiveRecord::Migration[6.0]
  def change
    add_index :user_api_keys, :key_hash, unique: true
  end
end
