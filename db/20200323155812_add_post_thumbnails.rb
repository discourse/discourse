# frozen_string_literal: true

# class AddPostThumbnails < ActiveRecord::Migration[6.0]
#   def change
#     create_table :post_thumbnails do |t|
#       t.references :posts, foreign_key: { to_table: :posts, delete: :cascade }, null: false
#       t.references :optimized_image, foreign_key: { to_table: :optimized_images, delete: :cascade }, null: false
#     end

#   end
# end
