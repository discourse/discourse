# frozen_string_literal: true

class AddPostThumbnails < ActiveRecord::Migration[6.0]
  def change
    add_table :post_thumbnails do |t|
      t.references :posts, foreign_key: { to_table: :posts }, null: false
    end

  end
end
