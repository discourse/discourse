# frozen_string_literal: true

class RemoveEnableUpcomingChangesSiteSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enable_upcoming_changes'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
