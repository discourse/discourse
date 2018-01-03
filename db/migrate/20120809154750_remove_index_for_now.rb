class RemoveIndexForNow < ActiveRecord::Migration[4.2]
  def up
    remove_index "posts", ["forum_thread_id", "post_number"]
    add_index "posts", ["forum_thread_id", "post_number"], unique: false
  end

  def down
    remove_index "posts", ["forum_thread_id", "post_number"]
    add_index "posts", ["forum_thread_id", "post_number"], unique: true
  end
end
