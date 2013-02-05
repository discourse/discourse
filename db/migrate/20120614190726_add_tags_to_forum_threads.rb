class AddTagsToForumThreads < ActiveRecord::Migration
  def change
    add_column :forum_threads, :tag, :string, null: true, limit: 25
  end
end
