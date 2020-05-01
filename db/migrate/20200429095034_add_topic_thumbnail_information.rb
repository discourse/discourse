# frozen_string_literal: true

class AddImageUploadIdToPostsAndTopics < ActiveRecord::Migration[6.0]
  def change
    add_reference :posts, :image_upload
    add_reference :topics, :image_upload

    add_column :theme_modifier_sets, :topic_thumbnail_sizes, :string, array: true

    create_table :topic_thumbnails do |t|
      t.references :upload, null: false
      t.references :optimized_image, null: true
      t.integer :max_width, null: false
      t.integer :max_height, null: false
    end

    add_index :topic_thumbnails, [:upload_id, :max_width, :max_height], name: :unique_topic_thumbnails, unique: true
  end
end
