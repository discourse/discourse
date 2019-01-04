class AddEtagToUploads < ActiveRecord::Migration[5.2]
  def change
    add_column :uploads, :etag, :string
    add_index :uploads, [:etag]

    add_column :optimized_images, :etag, :string
    add_index :optimized_images, [:etag]
  end
end
