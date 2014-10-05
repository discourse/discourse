class AddPostAndTopicCountsToUserStat < ActiveRecord::Migration
  def up
    add_column :user_stats, :post_count, :integer, default: 0, null: false
    add_column :user_stats, :topic_count, :integer, default: 0, null: false

    execute <<-SQL
      UPDATE user_stats
      SET post_count = pc.count
      FROM (SELECT user_id, COUNT(*) AS count FROM posts GROUP BY user_id) AS pc
      WHERE pc.user_id = user_stats.user_id
    SQL

    execute <<-SQL
      UPDATE user_stats
      SET topic_count = tc.count
      FROM (SELECT user_id, COUNT(*) AS count FROM topics GROUP BY user_id) AS tc
      WHERE tc.user_id = user_stats.user_id
    SQL
  end

  def down
    remove_column :user_stats, :post_count
    remove_column :user_stats, :topic_count
  end
end
