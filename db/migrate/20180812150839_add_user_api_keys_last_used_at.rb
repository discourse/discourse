class AddUserApiKeysLastUsedAt < ActiveRecord::Migration[5.2]
  def change
    add_column :user_api_keys, :last_used_at, :datetime, null: false, default: -> { 'CURRENT_TIMESTAMP' }
  end
end
