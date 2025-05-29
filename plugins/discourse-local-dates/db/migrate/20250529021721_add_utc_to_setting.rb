# frozen_string_literal: true
class AddUtcToSetting < ActiveRecord::Migration[7.2]
  def up
    # we changed the setting so UTC is no longer appeneded
    execute <<~SQL
      UPDATE site_settings
      SET value = value || ' UTC'
      WHERE name = 'discourse_local_dates_email_format'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE site_settings
      SET value = REPLACE(value, ' UTC', '')
      WHERE name = 'discourse_local_dates_email_format'
    SQL
  end
end
