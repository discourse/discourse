class AddPostNumberToBookmarks < ActiveRecord::Migration
  def change
    drop_table :bookmarks

    create_table :bookmarks do |t|
      t.integer :user_id, null: false
      t.integer :forum_thread_id, null: false
      t.integer :post_number, null: false
      t.timestamps
    end

    add_index :bookmarks, [:user_id, :forum_thread_id, :post_number], unique: true
  end
end
