class MigrateBookmarksToPostActions < ActiveRecord::Migration
  def up
    execute "insert into post_actions(user_id, post_action_type_id, post_id, created_at, updated_at)
    select distinct b.user_id, #{PostActionType.bookmark.id} , p.id, b.created_at, b.updated_at 
from bookmarks b
join posts p on p.forum_thread_id = b.forum_thread_id and p.post_number = b.post_number"
    drop_table "bookmarks"
  end

  def down
    # I can reverse this, but not really worth the work
    raise ActiveRecord::IrriversableMigration
  end
end
