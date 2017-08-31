class MoveTrackingOptionsToUserOptions < ActiveRecord::Migration[4.2]
  def change
    add_column :user_options, :auto_track_topics_after_msecs, :integer
    add_column :user_options, :new_topic_duration_minutes, :integer
    add_column :user_options, :last_redirected_to_top_at, :datetime

    execute <<SQL
    UPDATE user_options
    SET auto_track_topics_after_msecs = users.auto_track_topics_after_msecs,
        new_topic_duration_minutes = users.new_topic_duration_minutes,
        last_redirected_to_top_at = users.last_redirected_to_top_at
    FROM users
    WHERE users.id = user_options.user_id
SQL
  end
end
