# frozen_string_literal: true

class ConvertSiteContactGroupNameToId < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE site_settings
         SET value = groups.id::text, updated_at = NOW()
        FROM groups
       WHERE site_settings.name = 'site_contact_group_name'
         AND btrim(site_settings.value) <> ''
         AND lower(groups.name) = lower(btrim(site_settings.value))
         AND NOT EXISTS (
               SELECT 1
                 FROM groups existing
                WHERE existing.id::text = btrim(site_settings.value)
             )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
