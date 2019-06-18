# frozen_string_literal: true

class AddAuthTokenCreatedAtToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :auth_token_created_at, :datetime, null: true
  end
end
