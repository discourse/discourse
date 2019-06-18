# frozen_string_literal: true

class CreateForumThreadLinks < ActiveRecord::Migration[4.2]
  def change
    create_table :forum_thread_links do |t|
      t.integer :forum_thread_id, null: false
      t.integer :post_id, null: false
      t.integer :user_id, null: false
      t.string  :url, limit: 500, null: false
      t.string  :domain, limit: 100, null: false
      t.boolean :internal, null: false, default: false
      t.integer :link_forum_thread_id, null: true
      t.timestamps null: false
    end

    add_index :forum_thread_links, :forum_thread_id
  end
end
