# frozen_string_literal: true

class AddAutoImageCaptionToUserOptions < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :auto_image_caption, :boolean, default: false, null: false
  end
end
