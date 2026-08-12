# frozen_string_literal: true

class RemoveIncludeExpiredSiteSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'include_expired_events_on_calendar'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
