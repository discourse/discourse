class AddEtagToUploads < ActiveRecord::Migration[5.2]
  def change
    add_column :uploads, :etag, :string
    add_index :uploads, [:etag]

    add_column :optimized_images, :etag, :string
    add_index :optimized_images, [:etag]
  end

  def down
    remove_column :uploads, :etag
    remove_index :uploads, [:etag]

    remove_column :optimized_images, :etag
    remove_index :optimized_images, [:etag]
  end
end
