class RemoveLastPostId < ActiveRecord::Migration
  def up
    remove_column :forum_threads, :last_post_id
  end

  def down
    add_column :forum_threads, :last_post_id, :integer, default: 0
  end
end
