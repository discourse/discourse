# frozen_string_literal: true

class AddExpiresAtToUserApiKeys < ActiveRecord::Migration[8.0]
  def change
    add_column :user_api_keys, :expires_at, :datetime
  end
end
