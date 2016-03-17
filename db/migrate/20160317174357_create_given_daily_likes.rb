class CreateGivenDailyLikes < ActiveRecord::Migration
  def up
    create_table :given_daily_likes, id: false, force: true do |t|
      t.integer :user_id, null: false
      t.integer :likes_given, null: false
      t.date    :given_date, null: false
      t.boolean :limit_reached, null: false, default: false
    end
    add_index :given_daily_likes, [:user_id, :given_date], unique: true
    add_index :given_daily_likes, [:limit_reached, :user_id]

    max_likes_rows = execute("SELECT value FROM site_settings WHERE name = 'max_likes_per_day'")
    if max_likes_rows && max_likes_rows.cmd_tuples > 0
      max_likes = max_likes_rows[0]['value'].to_i
    end
    max_likes ||= 50

    execute "INSERT INTO given_daily_likes (user_id, likes_given, limit_reached, given_date)
             SELECT pa.user_id,
                    COUNT(*),
                    CASE WHEN COUNT(*) >= #{max_likes} THEN true
                    ELSE false
                    END,
                    pa.created_at::date
             FROM post_actions AS pa
             WHERE pa.post_action_type_id = 2
               AND pa.deleted_at IS NULL
             GROUP BY pa.user_id, pa.created_at::date"
  end

  def down
    drop_table :given_daily_likes
  end
end
