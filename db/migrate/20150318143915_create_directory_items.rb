class CreateDirectoryItems < ActiveRecord::Migration
  def change
    create_table :directory_items, force: true do |t|
      t.integer :period_type, null: false
      t.references :user, null: false
      t.integer :likes_received, null: false
      t.integer :likes_given, null: false
      t.integer :topics_entered, null: false
      t.integer :topic_count, null: false
      t.integer :post_count, null: false
      t.timestamps
    end

    add_index :directory_items, :period_type
  end
end
