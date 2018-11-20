class AddRevokedAtToUserApiKeys < ActiveRecord::Migration[4.2]
  def change
    add_column :user_api_keys, :revoked_at, :datetime
  end
end
