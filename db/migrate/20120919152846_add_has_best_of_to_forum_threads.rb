class AddHasBestOfToForumThreads < ActiveRecord::Migration[4.2]

  def change
    add_column :forum_threads, :has_best_of, :boolean, default: false, null: false
    change_column :posts, :score, :float
  end

end
