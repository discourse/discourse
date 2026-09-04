# frozen_string_literal: true

class AddColsToAdminDashboardReports < ActiveRecord::Migration[8.0]
  def change
    add_column :admin_dashboard_reports, :cols, :integer, null: false, default: 1
  end
end
