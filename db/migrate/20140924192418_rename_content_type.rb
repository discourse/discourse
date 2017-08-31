class RenameContentType < ActiveRecord::Migration[4.2]
  def change
    rename_column :site_contents, :content_type, :text_type
    rename_column :site_contents, :content, :value
    rename_table :site_contents, :site_texts
  end
end
