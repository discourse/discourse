class AddFilesizeToOptimizedImages < ActiveRecord::Migration[5.2]
  def change
    add_column :optimized_images, :filesize, :integer
    add_column :uploads, :thumbnail_width, :integer
    add_column :uploads, :thumbnail_height, :integer
  end
end
