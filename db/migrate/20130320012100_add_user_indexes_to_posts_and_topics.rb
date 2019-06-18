# frozen_string_literal: true

class AddUserIndexesToPostsAndTopics < ActiveRecord::Migration[4.2]
  def up
    execute "CREATE INDEX idx_posts_user_id_deleted_at
              ON posts(user_id) WHERE deleted_at IS NULL"

    execute "CREATE INDEX idx_topics_user_id_deleted_at
              ON topics(user_id) WHERE deleted_at IS NULL"
  end

  def down
    execute "DROP INDEX idx_posts_user_id_deleted_at"
    execute "DROP INDEX idx_topics_user_id_deleted_at"
  end
end
