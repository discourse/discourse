class DropQueuedPosts < ActiveRecord::Migration[5.2]
  def up
    drop_table :queued_posts
  end
end
