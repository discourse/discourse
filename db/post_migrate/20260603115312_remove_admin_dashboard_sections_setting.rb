# frozen_string_literal: true
class RemoveAdminDashboardSectionsSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'admin_dashboard_sections'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
