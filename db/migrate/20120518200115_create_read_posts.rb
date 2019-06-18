# frozen_string_literal: true

class CreateReadPosts < ActiveRecord::Migration[4.2]
  def up
    create_table :read_posts, id: false do |t|
      t.integer :forum_thread_id, null: false
      t.integer :user_id, null: false
      t.column :page, :integer, null: false
      t.column :seen, :integer, null: false
    end

    add_index :read_posts, [:forum_thread_id, :user_id, :page], unique: true
  end

  def down
    drop_table :read_posts
  end

end
