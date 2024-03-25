# frozen_string_literal: true

module Jobs
  class SyncTopicUserBookmarked < ::Jobs::Base
    def execute(args = {})
      raise Discourse::InvalidParameters.new(:topic_id) unless args[:topic_id].present?

      bookmarks_exist = DB.exec(<<~SQL, topic_id: args[:topic_id]) > 0
        SELECT 1
        FROM bookmarks
        LEFT JOIN posts ON posts.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'
        LEFT JOIN topics ON topics.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Topic'
        WHERE (topics.id = :topic_id OR posts.topic_id = :topic_id)
        AND posts.deleted_at IS NULL
        AND topics.deleted_at IS NULL
        LIMIT 1
      SQL

      return unless bookmarks_exist

      DB.exec(<<~SQL, topic_id: args[:topic_id])
        UPDATE topic_users
        SET bookmarked = CASE
          WHEN EXISTS (
            SELECT 1
            FROM bookmarks
            JOIN posts ON posts.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'
            WHERE posts.topic_id = topic_users.topic_id AND bookmarks.user_id = topic_users.user_id
            AND posts.deleted_at IS NULL
          ) OR EXISTS (
            SELECT 1
            FROM bookmarks
            WHERE bookmarks.bookmarkable_id = topic_users.topic_id AND bookmarks.bookmarkable_type = 'Topic'
            AND bookmarks.user_id = topic_users.user_id
          ) THEN true
          ELSE false
        END
        WHERE topic_users.topic_id = :topic_id;
      SQL
    end
  end
end
