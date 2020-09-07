# frozen_string_literal: true

class MigrateUserTopicTimersToBookmarkReminders < ActiveRecord::Migration[6.0]
  def up
    topic_timers_to_migrate = DB.query(<<~SQL, reminder_type: 5)
      SELECT topic_timers.id, topic_timers.topic_id, topic_timers.user_id, execute_at,
      posts.id AS first_post_id
      FROM topic_timers
      INNER JOIN topics ON topics.id = topic_timers.topic_id
      INNER JOIN posts ON posts.topic_id = topics.id AND posts.post_number = 1
      WHERE topics.deleted_at IS NULL
      AND topic_timers.deleted_at IS NULL
      AND topic_timers.status_type = :reminder_type
    SQL

    return if topic_timers_to_migrate.empty?

    topic_timer_tuples = topic_timers_to_migrate.map do |tt|
      "(#{tt.user_id}, #{tt.topic_id})"
    end.join(", ")

    existing_bookmarks = DB.query(<<~SQL)
      SELECT bookmarks.id, reminder_at, reminder_type,
             bookmarks.topic_id, post_id, bookmarks.user_id, posts.post_number
      FROM bookmarks
      INNER JOIN posts ON posts.id = bookmarks.post_id
      WHERE (bookmarks.user_id, bookmarks.topic_id) IN (#{topic_timer_tuples})
    SQL

    new_bookmarks = []
    topic_timers_to_migrate.each do |tt|
      bookmark = existing_bookmarks.find do |bm|

        # we only care about existing topic-level bookmarks here
        # because topic timers are (funnily enough) topic-level
        bm.topic_id == tt.topic_id && bm.user_id == tt.user_id && bm.post_number == 1
      end

      if !bookmark
        # create one
        now = Time.zone.now
        new_bookmarks << {
          user_id: tt.user_id,
          topic_id: tt.topic_id,
          post_id: tt.first_post_id,
          reminder_at: tt.execute_at,
          reminder_type: 6, # custom
          created_at: now,
          updated_at: now
        }
      else
        if !bookmark.reminder_at
          Bookmark.find(bookmark.id).update(reminder_at: tt.execute_at, reminder_type: 6)
        end

        # if there is a bookmark with reminder already do nothing,
        # we do not need to migrate the topic timer because it would
        # cause a conflict
      end
    end

    Bookmark.insert_all(new_bookmarks)

    # TODO(2021-01-07): delete leftover trashed records
    # trash these so the records are kept around for any possible data issues,
    # they can be deleted in a few months
    topic_timers_to_migrate_ids = topic_timers_to_migrate.map(&:id)
    TopicTimer.where(id: topic_timers_to_migrate_ids).update_all(
      deleted_at: Time.zone.now, deleted_by: Discourse.system_user
    )

    # Cancel all the outstanding jobs as well.
    topic_timers_to_migrate_ids.each do |ttid|
      Jobs.cancel_scheduled_job(:topic_reminder, topic_timer_id: ttid)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
