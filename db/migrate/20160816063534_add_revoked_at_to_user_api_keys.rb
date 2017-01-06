class AddRevokedAtToUserApiKeys < ActiveRecord::Migration
  def change
    add_column :user_api_keys, :revoked_at, :datetime
  end
end
