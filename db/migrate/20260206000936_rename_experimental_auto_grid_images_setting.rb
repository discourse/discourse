# frozen_string_literal: true

class RenameExperimentalAutoGridImagesSetting < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET name = 'enable_auto_grid_images'
      WHERE name = 'experimental_auto_grid_images'
    SQL

    execute <<~SQL
      UPDATE upcoming_change_events
      SET upcoming_change_name = 'enable_auto_grid_images'
      WHERE upcoming_change_name = 'experimental_auto_grid_images'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
