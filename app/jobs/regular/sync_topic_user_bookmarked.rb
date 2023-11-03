# frozen_string_literal: true

module Jobs
  class SyncTopicUserBookmarked < ::Jobs::Base
    def execute(args = {})
      DB.exec(<<~SQL, topic_id: args[:topic_id])
        WITH bookmarks_count AS (
          SELECT bookmarks.user_id, COUNT(*)
          FROM bookmarks
          LEFT JOIN posts ON posts.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'
          LEFT JOIN topics ON (topics.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Topic') OR
           (topics.id = posts.topic_id)
           WHERE (topics.id = :topic_id OR posts.topic_id = :topic_id)
           AND posts.deleted_at IS NULL AND topics.deleted_at IS NULL
          GROUP BY bookmarks.user_id
        )
        UPDATE topic_users
        SET bookmarked = true
        FROM bookmarks_count
        WHERE topic_users.user_id = bookmarks_count.user_id AND topic_users.topic_id = :topic_id AND bookmarks_count.count > 0;

        UPDATE topic_users
        SET bookmarked = false
        WHERE topic_users.topic_id = :topic_id AND topic_users.bookmarked = true AND topic_users.user_id NOT IN (
          SELECT bookmarks.user_id
          FROM bookmarks
        );
      SQL
    end
  end
end
