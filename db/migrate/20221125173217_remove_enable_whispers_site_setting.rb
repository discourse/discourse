# frozen_string_literal: true

class RemoveEnableWhispersSiteSetting < ActiveRecord::Migration[7.0]
  def up
    # If enable_whispers was true, insert whispers_allowed_groups or add
    # staff group to whispers_allowed_groups. This is necessary to keep
    # the current behavior which has a bypass for staff members.
    execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      SELECT 'whispers_allowed_groups', '20', '3', created_at, NOW()
      FROM site_settings
      WHERE name = 'enable_whispers' AND value = 't'
      ON CONFLICT DO NOTHING
    SQL

    execute <<~SQL
      UPDATE site_settings
      SET value = array_to_string(array_append(string_to_array(value, '|'), '3'), '|')
      WHERE name = 'whispers_allowed_groups' AND
            EXISTS(SELECT 1 FROM site_settings WHERE name = 'enable_whispers' AND value = 't') AND
            NOT '3' = ANY(string_to_array(value, '|'))
    SQL

    # If enable_whispers was false, reset whispers_allowed_groups
    execute <<~SQL
      UPDATE site_settings
      SET value = ''
      WHERE name = 'whispers_allowed_groups' AND
            NOT EXISTS(SELECT 1 FROM site_settings WHERE name = 'enable_whispers' AND value = 't')
    SQL

    # Delete enable_whispers site setting
    execute <<~SQL
      DELETE FROM site_settings WHERE name = 'enable_whispers'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
