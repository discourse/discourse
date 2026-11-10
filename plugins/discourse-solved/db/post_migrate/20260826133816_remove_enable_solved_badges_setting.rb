# frozen_string_literal: true

class RemoveEnableSolvedBadgesSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enable_solved_badges'"
    execute "DELETE FROM site_setting_groups WHERE name = 'enable_solved_badges'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
