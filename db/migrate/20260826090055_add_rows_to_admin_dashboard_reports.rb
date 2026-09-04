# frozen_string_literal: true

class AddRowsToAdminDashboardReports < ActiveRecord::Migration[8.0]
  def change
    add_column :admin_dashboard_reports, :rows, :integer, null: false, default: 1
  end
end
