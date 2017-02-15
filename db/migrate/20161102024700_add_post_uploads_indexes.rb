class AddPostUploadsIndexes < ActiveRecord::Migration
  def change
    add_index :post_uploads, :post_id
    add_index :post_uploads, :upload_id
  end
end
