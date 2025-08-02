# frozen_string_literal: true

class RenameAuthTokenCreatedAt < ActiveRecord::Migration[4.2]
  def change
    rename_column :users, :auth_token_created_at, :auth_token_updated_at
  end
end
