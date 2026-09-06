# frozen_string_literal: true

class CopyCalendarEnabledToDiscourseEventsEnabled < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'discourse_events_enabled', data_type, value, created_at, updated_at
      FROM site_settings
      WHERE name = 'calendar_enabled'
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
