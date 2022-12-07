# frozen_string_literal: true

class RemoveEnableWhispersSiteSetting < ActiveRecord::Migration[7.0]
  def up
    # If enable_whispers is enabled, add 'staff' group to whispers_allowed_groups
    # if it was not already added.
    execute <<~SQL
      UPDATE site_settings
      SET value = array_to_string(array_append(string_to_array(value, '|'), '3'), '|')
      WHERE name = 'whispers_allowed_groups' AND
            EXISTS(SELECT 1 FROM site_settings WHERE name = 'enable_whispers' AND value = 't') AND
            NOT '3' = ANY(string_to_array(value, '|'))
    SQL

    # If enable_whispers is disabled, reset whispers_allowed_groups
    execute <<~SQL
      UPDATE site_settings
      SET value = ''
      WHERE name = 'whispers_allowed_groups' AND
            EXISTS(SELECT 1 FROM site_settings WHERE name = 'enable_whispers' AND value = 'f')
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
