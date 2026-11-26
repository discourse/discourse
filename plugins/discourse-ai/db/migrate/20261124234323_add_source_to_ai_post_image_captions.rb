# frozen_string_literal: true

class AddSourceToAiPostImageCaptions < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_post_image_captions, :source, :string, default: "unknown", null: false
  end
end
