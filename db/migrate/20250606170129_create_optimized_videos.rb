# frozen_string_literal: true

class CreateOptimizedVideos < ActiveRecord::Migration[7.2]
  def change
    create_table :optimized_videos do |t|
      t.integer :upload_id, null: false
      t.integer :optimized_upload_id, null: false
      t.string :adapter
      t.timestamps
    end

    add_index :optimized_videos, :upload_id
    add_index :optimized_videos, :optimized_upload_id
    add_index :optimized_videos, %i[upload_id adapter], unique: true

    add_foreign_key :optimized_videos, :uploads, column: :upload_id
    add_foreign_key :optimized_videos, :uploads, column: :optimized_upload_id
  end
end
