class RenameCsvExportLogsToUserExports < ActiveRecord::Migration
  def change
    rename_table :csv_export_logs, :user_exports
  end
end
