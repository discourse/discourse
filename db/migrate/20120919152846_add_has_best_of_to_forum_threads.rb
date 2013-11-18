class AddHasBestOfToForumThreads < ActiveRecord::Migration

  def change
    add_column :forum_threads, :has_summary, :boolean, default: false, null: false
    change_column :posts, :score, :float
  end

end
