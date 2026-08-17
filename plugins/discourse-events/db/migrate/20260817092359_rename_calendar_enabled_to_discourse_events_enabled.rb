# frozen_string_literal: true

class RenameCalendarEnabledToDiscourseEventsEnabled < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE site_settings SET name = 'discourse_events_enabled' WHERE name = 'calendar_enabled'"
  end

  def down
    execute "UPDATE site_settings SET name = 'calendar_enabled' WHERE name = 'discourse_events_enabled'"
  end
end
