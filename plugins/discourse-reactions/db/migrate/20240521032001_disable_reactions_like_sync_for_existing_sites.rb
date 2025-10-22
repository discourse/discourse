# frozen_string_literal: true

class DisableReactionsLikeSyncForExistingSites < ActiveRecord::Migration[7.0]
  def up
    # 5 is bool data_type
    execute <<~SQL if Migration::Helpers.existing_site?
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES('discourse_reactions_like_sync_enabled', 5, 'f', NOW(), NOW())
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
