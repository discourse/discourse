# frozen_string_literal: true

class AddImageUploadIdToPostsAndTopics < ActiveRecord::Migration[6.0]
  def change
    add_reference :posts, :image_upload
    add_reference :topics, :image_upload

    add_column :theme_modifier_sets, :topic_thumbnail_sizes, :string, array: true
  end
end
