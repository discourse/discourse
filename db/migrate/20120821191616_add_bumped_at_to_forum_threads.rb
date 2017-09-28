class AddBumpedAtToForumThreads < ActiveRecord::Migration[4.2]
  def change
    add_column :forum_threads, :bumped_at, :datetime
    execute "UPDATE forum_threads SET bumped_at = last_posted_at"
    change_column :forum_threads, :bumped_at, :datetime, null: false

    remove_index :forum_threads, :last_posted_at
    add_index :forum_threads, :bumped_at, order: { bumped_at: :desc }
  end
end
