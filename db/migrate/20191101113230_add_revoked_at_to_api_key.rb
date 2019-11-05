# frozen_string_literal: true
class AddRevokedAtToApiKey < ActiveRecord::Migration[5.2]
  def up
    add_column :api_keys, :revoked_at, :datetime
    add_column :api_keys, :description, :text

    execute "INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
             VALUES ('api_key_last_used_epoch', 1, now(), now(), now())"

    remove_index :api_keys, :user_id # Remove unique index
    add_index :api_keys, :user_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
