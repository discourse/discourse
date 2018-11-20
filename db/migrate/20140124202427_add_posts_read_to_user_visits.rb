class AddPostsReadToUserVisits < ActiveRecord::Migration[4.2]
  def up
    add_column :user_visits, :posts_read, :integer, default: 0

    # Can't accurately back-fill this column. Assume everyone read at least one post per visit.
    execute "UPDATE user_visits SET posts_read = 1"
  end

  def down
    remove_column :user_visits, :posts_read
  end
end
