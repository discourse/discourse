class CreateCsvExportLogs < ActiveRecord::Migration
  def change
    create_table :csv_export_logs do |t|
      t.string :export_type, null: false
      t.integer :user_id, null: false
      t.timestamps
    end
  end
end
