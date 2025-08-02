# frozen_string_literal: true

module Jobs
  class SyncTopicUserBookmarked < ::Jobs::Base
    def execute(args = {})
      raise Discourse::InvalidParameters.new(:topic_id) if args[:topic_id].blank?

      DB.exec(<<~SQL, topic_id: args[:topic_id])
        SELECT bookmarks.user_id, COUNT(*)
        INTO TEMP TABLE tmp_sync_topic_user_bookmarks
        FROM bookmarks
        LEFT JOIN posts ON posts.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'
        LEFT JOIN topics ON (topics.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Topic') OR
         (topics.id = posts.topic_id)
        WHERE (topics.id = :topic_id OR posts.topic_id = :topic_id)
        AND posts.deleted_at IS NULL AND topics.deleted_at IS NULL
        GROUP BY bookmarks.user_id;

        UPDATE topic_users
        SET bookmarked = true
        FROM tmp_sync_topic_user_bookmarks
        WHERE topic_users.user_id = tmp_sync_topic_user_bookmarks.user_id AND
          topic_users.topic_id = :topic_id AND
          tmp_sync_topic_user_bookmarks.count > 0;

        UPDATE topic_users
        SET bookmarked = false
        FROM tmp_sync_topic_user_bookmarks
        WHERE topic_users.topic_id = :topic_id AND
          topic_users.bookmarked = true AND
          topic_users.user_id NOT IN (
            SELECT tmp_sync_topic_user_bookmarks.user_id
            FROM tmp_sync_topic_user_bookmarks
          );

        DROP TABLE tmp_sync_topic_user_bookmarks;
      SQL
    end
  end
end
