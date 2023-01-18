# frozen_string_literal: true

class SetDisableMailingListMode < ActiveRecord::Migration[6.0]
  def up
    result = execute "SELECT COUNT(*) FROM user_options WHERE mailing_list_mode"
    execute <<~SQL if result.first["count"] > 0
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('disable_mailing_list_mode', 5, 'f', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
