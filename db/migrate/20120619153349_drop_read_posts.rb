class DropReadPosts < ActiveRecord::Migration[4.2]
  def up
    drop_table :read_posts
  end

  def down
    create_table :read_posts, id: false do |t|
      t.integer :forum_thread_id, null: false
      t.integer :user_id, null: false
      t.column :page, :integer, null: false
      t.column :seen, :integer, null: false
    end
  end
end
