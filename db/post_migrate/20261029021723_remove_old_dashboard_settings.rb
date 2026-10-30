# frozen_string_literal: true
class RemoveOldDashboardSettings < ActiveRecord::Migration[8.1]
  SETTINGS = %w[
    dashboard_hidden_reports
    dashboard_visible_tabs
    dashboard_general_tab_activity_metrics
  ]

  def up
    execute(<<~SQL)
      DELETE FROM site_settings WHERE name IN ('#{SETTINGS.join("','")}')
    SQL

    execute(<<~SQL)
      DELETE FROM site_setting_groups WHERE name IN ('#{SETTINGS.join("','")}')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
