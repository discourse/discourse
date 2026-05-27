# frozen_string_literal: true

class AddUserIdToDiscourseRssPollingRssFeeds < ActiveRecord::Migration[8.0]
  SYSTEM_USER_ID = -1

  def up
    add_column :discourse_rss_polling_rss_feeds, :user_id, :bigint
    add_index :discourse_rss_polling_rss_feeds, :user_id

    execute <<~SQL
      UPDATE discourse_rss_polling_rss_feeds feeds
         SET user_id = users.id
        FROM users
       WHERE feeds.user_id IS NULL
         AND LOWER(users.username) = LOWER(feeds.author)
    SQL

    # Unresolvable rows fall back to the system user so polling keeps
    # working; admins can reassign from the UI afterwards.
    execute <<~SQL
      UPDATE discourse_rss_polling_rss_feeds
         SET user_id = #{SYSTEM_USER_ID}
       WHERE user_id IS NULL
    SQL

    change_column_default :discourse_rss_polling_rss_feeds, :author, nil
    Migration::ColumnDropper.mark_readonly(:discourse_rss_polling_rss_feeds, :author)
  end

  def down
    Migration::ColumnDropper.drop_readonly(:discourse_rss_polling_rss_feeds, :author)
    remove_index :discourse_rss_polling_rss_feeds, :user_id
    remove_column :discourse_rss_polling_rss_feeds, :user_id
  end
end
