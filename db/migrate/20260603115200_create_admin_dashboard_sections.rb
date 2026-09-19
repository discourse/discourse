# frozen_string_literal: true
class CreateAdminDashboardSections < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_dashboard_sections do |t|
      t.string :section_id, null: false
      t.integer :position, null: false
      t.boolean :visible, null: false, default: true
      t.timestamps
    end

    add_index :admin_dashboard_sections, :section_id, unique: true
  end
end
