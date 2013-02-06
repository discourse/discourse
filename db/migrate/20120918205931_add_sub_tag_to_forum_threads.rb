class AddSubTagToForumThreads < ActiveRecord::Migration
  def change
    add_column :forum_threads, :sub_tag, :string
    add_index :forum_threads, [:category_id, :sub_tag, :bumped_at]
  end
end
