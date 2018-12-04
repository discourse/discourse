class AddEtagToUploads < ActiveRecord::Migration[5.2]
  def change
    add_column :uploads, :etag, :string
    execute "CREATE INDEX index_uploads_on_etag ON uploads(etag)"
  end

  def down
    remove_column :uploads, :etag
    execute "DROP INDEX index_uploads_on_etag"
  end
end
