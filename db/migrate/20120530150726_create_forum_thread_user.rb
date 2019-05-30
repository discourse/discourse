# frozen_string_literal: true

class CreateForumThreadUser < ActiveRecord::Migration[4.2]
  def up
    create_table :forum_thread_users, id: false do |t|
      t.integer  :user_id, null: false
      t.integer  :forum_thread_id, null: false
      t.boolean  :starred, null: false, default: false
      t.boolean  :posted, null: false, default: false
      t.integer  :last_read_post_number, null: false, default: 1
      t.timestamps null: false
    end

    execute "DELETE FROM read_posts"

    add_index :forum_thread_users, [:forum_thread_id, :user_id], unique: true

    drop_table :stars
    drop_table :last_read_posts
  end

  def down
    drop_table :forum_thread_users

    create_table :stars, id: false do |t|
      t.integer  :parent_id, null: false
      t.string   :parent_type, limit: 50, null: false
      t.integer  :user_id, null: true
      t.timestamps null: false
    end

    add_index :stars, [:parent_id, :parent_type, :user_id]

    create_table :last_read_posts do |t|
      t.integer :user_id, null: false
      t.integer :forum_thread_id, null: false
      t.integer :post_number, null: false
      t.timestamps null: false
    end

    add_index :last_read_posts, [:user_id, :forum_thread_id], unique: true
  end
end
