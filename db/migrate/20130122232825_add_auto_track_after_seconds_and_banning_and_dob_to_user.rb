class AddAutoTrackAfterSecondsAndBanningAndDobToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :banned_at, :datetime
    add_column :users, :banned_till, :datetime
    add_column :users, :date_of_birth, :date
    add_column :users, :auto_track_topics_after_msecs, :integer
    add_column :users, :views, :integer, null: false, default: 0

    remove_column :users, :auto_track_topics

    add_column :topic_users, :total_msecs_viewed, :integer, null: false, default: 0

    execute 'update topic_users set total_msecs_viewed =
       (
         select coalesce(sum(msecs) ,0)
         from post_timings t
         where topic_users.topic_id = t.topic_id and topic_users.user_id = t.user_id
       )'
  end
end
