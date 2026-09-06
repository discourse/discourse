# frozen_string_literal: true
class AddSettingsToAdminDashboardSections < ActiveRecord::Migration[8.0]
  def change
    add_column :admin_dashboard_sections, :settings, :jsonb, null: false, default: {}
  end
end
