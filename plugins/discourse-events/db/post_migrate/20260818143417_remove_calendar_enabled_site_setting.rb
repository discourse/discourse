# frozen_string_literal: true

class RemoveCalendarEnabledSiteSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'calendar_enabled'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
