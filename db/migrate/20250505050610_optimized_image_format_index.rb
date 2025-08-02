# frozen_string_literal: true
class OptimizedImageFormatIndex < ActiveRecord::Migration[7.2]
  def up
    remove_index :optimized_images, name: "index_optimized_images_on_upload_id_and_width_and_height"
    add_index :optimized_images,
              %i[upload_id width height extension],
              name: "index_optimized_images_unique",
              unique: true
  end

  def down
    remove_index :optimized_images, name: "index_optimized_images_unique"
    add_index :optimized_images,
              %i[upload_id width height],
              name: "index_optimized_images_on_upload_id_and_width_and_height"
  end
end
