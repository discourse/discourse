class MigratePosted < ActiveRecord::Migration
  def up
    Post.all.each do |p|
      ForumThreadUser.change(p.user, p.forum_thread_id, posted: true)
    end
  end

  def down
  end
end
