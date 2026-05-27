# frozen_string_literal: true

class RenameExperimentalImpersonationSetting < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET name = 'impersonate_without_logout'
      WHERE name = 'experimental_impersonation'
    SQL

    execute <<~SQL
      UPDATE upcoming_change_events
      SET upcoming_change_name = 'impersonate_without_logout'
      WHERE upcoming_change_name = 'experimental_impersonation'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
