# frozen_string_literal: true

class CreateOptimizedVideos < ActiveRecord::Migration[7.2]
  def change
    create_table :optimized_videos do |t|
      t.string :sha1
      t.string :extension
      t.integer :upload_id
      t.string :url
      t.integer :filesize
      t.string :etag

      t.timestamps
    end
  end
end
