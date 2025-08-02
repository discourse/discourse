# frozen_string_literal: true

class CreateForumThreads < ActiveRecord::Migration[4.2]
  def change
    create_table :forum_threads do |t|
      t.integer :forum_id, null: false
      t.string :title, null: false
      t.integer :last_post_id
      t.datetime :last_posted_at
      t.timestamps null: false
    end
  end
end
