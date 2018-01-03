class AddTagsToForumThreads < ActiveRecord::Migration[4.2]
  def change
    add_column :forum_threads, :tag, :string, null: true, limit: 25
  end
end
