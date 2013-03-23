class CorrectIndexingOnPosts < ActiveRecord::Migration
  def up
      execute "update posts pp
set post_number = c.real_number
from
(
	select p1.id, count(*) real_number from posts p1
	join posts p2 on p1.forum_thread_id = p2.forum_thread_id
	where p2.id <= p1.id and p1.forum_thread_id = p2.forum_thread_id
        group by p1.id
) as c
where pp.id = c.id and pp.post_number <> c.real_number"

    remove_index "posts", ["forum_thread_id","post_number"]

    # this needs to be unique if it is not we can not use post_number to identify a post
    add_index "posts", ["forum_thread_id","post_number"], unique: true

  end

  def down
  end
end
