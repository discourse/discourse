class AddDeletedAtToForumThreads < ActiveRecord::Migration
  def change
    add_column :forum_threads, :deleted_at, :datetime
  end
end
