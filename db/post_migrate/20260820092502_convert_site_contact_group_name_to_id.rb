# frozen_string_literal: true

class ConvertSiteContactGroupNameToId < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE site_settings
         SET value = groups.id::text, updated_at = NOW()
        FROM groups
       WHERE site_settings.name = 'site_contact_group_name'
         AND lower(site_settings.value) = lower(groups.name)
         AND site_settings.value NOT IN (SELECT id::text FROM groups)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
