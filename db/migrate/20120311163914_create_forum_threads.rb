class CreateForumThreads < ActiveRecord::Migration
  def change
    create_table :forum_threads do |t|
      t.integer :forum_id, null: false
      t.string :title, null: false
      t.integer :last_post_id
      t.datetime :last_posted_at
      t.timestamps
    end
  end
end
