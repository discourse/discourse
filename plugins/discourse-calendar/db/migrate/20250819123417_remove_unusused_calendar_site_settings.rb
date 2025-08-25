# frozen_string_literal: true

class RemoveUnususedCalendarSiteSettings < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'events_max_rows'"
    execute "DELETE FROM site_settings WHERE name = 'enable_timezone_offset_for_calendar_events'"
    execute "DELETE FROM site_settings WHERE name = 'default_timezone_offset_user_option'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
