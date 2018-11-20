class AddExtensionToUploads < ActiveRecord::Migration[4.2]
  def up
    add_column :uploads, :extension, :string, limit: 10
    execute "CREATE INDEX index_uploads_on_extension ON uploads(lower(extension))"
  end

  def down
    remove_column :uploads, :extension
    execute "DROP INDEX index_uploads_on_extension"
  end
end
