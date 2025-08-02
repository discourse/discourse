# frozen_string_literal: true

class CreateCsvExportLogs < ActiveRecord::Migration[4.2]
  def change
    create_table :csv_export_logs do |t|
      t.string :export_type, null: false
      t.integer :user_id, null: false
      t.timestamps null: false
    end
  end
end
