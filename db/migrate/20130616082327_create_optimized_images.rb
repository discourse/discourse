# frozen_string_literal: true

class CreateOptimizedImages < ActiveRecord::Migration[4.2]
  def up
    create_table :optimized_images do |t|
      t.string :sha, null: false
      t.string :ext, null: false
      t.integer :width, null: false
      t.integer :height, null: false
      t.integer :upload_id, null: false
    end

    add_index :optimized_images, :upload_id
    add_index :optimized_images, [:upload_id, :width, :height], unique: true
  end

  def down
    drop_table :optimized_images
  end
end
