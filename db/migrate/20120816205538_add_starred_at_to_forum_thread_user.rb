class AddStarredAtToForumThreadUser < ActiveRecord::Migration
  def up
    add_column :forum_thread_users, :starred_at, :datetime
    User.exec_sql 'update forum_thread_users f set starred_at = COALESCE(created_at, ?)
    from
      (
        select f1.forum_thread_id, f1.user_id, t.created_at from forum_thread_users f1
        left join forum_threads t on f1.forum_thread_id = t.id
      ) x
    where x.forum_thread_id = f.forum_thread_id and x.user_id = f.user_id', [DateTime.now]

    # probably makes sense to move this out to forum_thread_actions
    execute 'alter table forum_thread_users add constraint test_starred_at check(starred = false or starred_at is not null)'
  end

  def down
    execute 'alter table forum_thread_users drop constraint test_starred_at'
    remove_column :forum_thread_users, :starred_at
  end
end
