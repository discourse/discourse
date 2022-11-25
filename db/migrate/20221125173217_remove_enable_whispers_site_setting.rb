# frozen_string_literal: true

class RemoveEnableWhispersSiteSetting < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET value = array_to_string(array_append(string_to_array(value, '|'), '3'), '|')
      WHERE EXISTS(SELECT 1 FROM site_settings WHERE name = 'enable_whispers' AND value = 't') AND
            name = 'whispers_allowed_groups' AND
            NOT '3' = ANY(string_to_array(value, '|'))
    SQL

    execute <<~SQL
      DELETE FROM site_settings WHERE name = 'enable_whispers'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
