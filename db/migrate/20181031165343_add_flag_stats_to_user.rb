class AddFlagStatsToUser < ActiveRecord::Migration[5.2]
  def up
    add_column :user_stats, :flags_agreed, :integer, default: 0, null: false
    add_column :user_stats, :flags_disagreed, :integer, default: 0, null: false
    add_column :user_stats, :flags_ignored, :integer, default: 0, null: false

    sql = <<~SQL
      UPDATE user_stats
      SET flags_agreed = x.flags_agreed,
        flags_disagreed = x.flags_disagreed,
        flags_ignored = x.flags_ignored
      FROM (
        SELECT u.id AS user_id,
          SUM(CASE WHEN pa.disagreed_at IS NOT NULL THEN 1 ELSE 0 END) as flags_disagreed,
          SUM(CASE WHEN pa.agreed_at IS NOT NULL THEN 1 ELSE 0 END) as flags_agreed,
          SUM(CASE WHEN pa.deferred_at IS NOT NULL THEN 1 ELSE 0 END) as flags_ignored
        FROM post_actions AS pa
        INNER JOIN users AS u ON u.id = pa.user_id
        WHERE pa.post_action_type_id IN (#{PostActionType.notify_flag_types.values.join(', ')})
        AND pa.user_id > 0
        GROUP BY u.id
      ) AS x
      WHERE x.user_id = user_stats.user_id
    SQL

    execute sql
  end

  def down
    remove_column :user_stats, :flags_agreed
    remove_column :user_stats, :flags_disagreed
    remove_column :user_stats, :flags_ignored
  end
end
