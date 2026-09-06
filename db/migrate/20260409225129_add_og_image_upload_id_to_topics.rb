# frozen_string_literal: true
class AddOgImageUploadIdToTopics < ActiveRecord::Migration[8.0]
  def change
    add_column :topics, :og_image_upload_id, :bigint, null: true
  end
end
