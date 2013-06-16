class CreateOptimizedImages < ActiveRecord::Migration
  def up
    create_table :optimized_images do |t|
      t.string :sha, null: false
      t.string :ext, null: false
      t.integer :width, null: false
      t.integer :height, null: false
      t.integer :upload_id, null: false
    end

    add_index :optimized_images, :upload_id
  end

  def down
    drop_table :optimized_images
  end
end
