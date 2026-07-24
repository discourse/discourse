# frozen_string_literal: true

class CreateAdminDashboardReports < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_dashboard_reports do |t|
      t.integer :position, null: false
      t.string :source, null: false
      t.string :identifier, null: false
      t.timestamps
    end

    add_index :admin_dashboard_reports, %i[source identifier], unique: true
    add_index :admin_dashboard_reports, :position
  end
end
