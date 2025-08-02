# frozen_string_literal: true

class RenameUserExportColumn < ActiveRecord::Migration[4.2]
  def change
    rename_column :user_exports, :export_type, :file_name
  end
end
