# frozen_string_literal: true
class AddUtcToSetting < ActiveRecord::Migration[7.2]
  def up
    # we changed the setting so UTC is no longer appended, we append it now in the format
    execute <<~SQL
      UPDATE site_settings
      SET value = value || ' z'
      WHERE name = 'discourse_local_dates_email_format'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE site_settings
      SET value = REPLACE(value, ' z', '')
      WHERE name = 'discourse_local_dates_email_format'
    SQL
  end
end
