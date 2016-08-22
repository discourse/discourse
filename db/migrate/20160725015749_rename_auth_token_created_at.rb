class RenameAuthTokenCreatedAt < ActiveRecord::Migration
  def change
    rename_column :users, :auth_token_created_at, :auth_token_updated_at
  end
end
