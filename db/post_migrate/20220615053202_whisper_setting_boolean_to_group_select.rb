# frozen_string_literal: true

class WhisperSettingBooleanToGroupSelect < ActiveRecord::Migration[7.0]
  def up
    DB.exec(<<~SQL)
      UPDATE site_settings
      SET value = (SELECT id FROM groups WHERE name = 'staff' LIMIT 1), data_type = 20
      WHERE value = 't' AND data_type = 5 AND name = 'enable_whispers'
    SQL
  end

  def down
    DB.exec(<<~SQL)
      UPDATE site_settings
      SET value =  't', data_type = 5
      WHERE name = 'enable_whispers'
    SQL
  end
end
