class AddVoteCountToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :forum_threads, :vote_count, :integer, default: 0, null: false
    add_column :posts, :vote_count, :integer, default: 0, null: false
  end
end
