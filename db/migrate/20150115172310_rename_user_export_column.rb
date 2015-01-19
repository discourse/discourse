class RenameUserExportColumn < ActiveRecord::Migration
  def change
    rename_column :user_exports, :export_type, :file_name
  end
end
