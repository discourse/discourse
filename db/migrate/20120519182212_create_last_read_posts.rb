class CreateLastReadPosts < ActiveRecord::Migration[4.2]
  def change
    create_table :last_read_posts do |t|
      t.integer :user_id, null: false
      t.integer :forum_thread_id, null: false
      t.integer :post_number, null: false
      t.timestamps null: false
    end

    add_index :last_read_posts, [:user_id, :forum_thread_id], unique: true
  end
end
