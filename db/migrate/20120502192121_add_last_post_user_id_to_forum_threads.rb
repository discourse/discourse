# frozen_string_literal: true

class AddLastPostUserIdToForumThreads < ActiveRecord::Migration[4.2]

  def up
    add_column :forum_threads, :last_post_user_id, :integer

    execute "update forum_threads t
    set last_post_user_id = (select user_id from posts where forum_thread_id = t.Id order by post_number desc limit 1)"

    change_column :forum_threads, :last_post_user_id, :integer, null: false
  end

  def down
    remove_column :forum_threads, :last_post_user_id
  end

end
