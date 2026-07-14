# frozen_string_literal: true
class MoveUnifiedNewSettingFromGroups < ActiveRecord::Migration[8.0]
  def up
    # For sites with experimental_new_new_view_groups configured,
    # copy those groups to site_setting_groups for enable_unified_new
    # and enable the new setting
    execute(<<~SQL)
      INSERT INTO site_setting_groups (name, group_ids, created_at, updated_at)
      SELECT 'enable_unified_new', value, NOW(), NOW()
      FROM site_settings
      WHERE name = 'experimental_new_new_view_groups'
        AND value IS NOT NULL
        AND value != ''
      ON CONFLICT (name) DO NOTHING
    SQL

    # Enable the setting for sites that had groups configured
    execute(<<~SQL)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'enable_unified_new', 5, 't', NOW(), NOW()
      FROM site_settings
      WHERE name = 'experimental_new_new_view_groups'
        AND value IS NOT NULL
        AND value != ''
      ON CONFLICT (name) DO NOTHING
    SQL

    # Delete the old experimental setting
    execute("DELETE FROM site_settings WHERE name = 'experimental_new_new_view_groups'")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
