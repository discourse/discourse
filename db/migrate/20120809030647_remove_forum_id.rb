class RemoveForumId < ActiveRecord::Migration
  def up
    remove_column 'forum_threads', 'forum_id'
    remove_column 'categories', 'forum_id'
  end

  def down
    raise 'not reversible'
  end
end
