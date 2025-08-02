# frozen_string_literal: true

class RenameCsvExportLogsToUserExports < ActiveRecord::Migration[4.2]
  def change
    rename_table :csv_export_logs, :user_exports
  end
end
