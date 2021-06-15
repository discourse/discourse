# frozen_string_literal: true

module Jobs
  class SyncTopicUserBookmarked < ::Jobs::Base
    def execute(args = {})
      topic_id = args[:topic_id]

      DB.exec(<<~SQL, topic_id: topic_id)
        UPDATE topic_users SET bookmarked = true
        FROM bookmarks AS b
        INNER JOIN posts ON posts.id = b.post_id
        WHERE NOT topic_users.bookmarked AND
          posts.deleted_at IS NULL AND
          topic_users.topic_id = b.topic_id AND
          topic_users.user_id = b.user_id #{topic_id.present? ? "AND topic_users.topic_id = :topic_id" : ""}
      SQL

      DB.exec(<<~SQL, topic_id: topic_id)
        UPDATE topic_users SET bookmarked = false
        WHERE topic_users.bookmarked AND
          (
            SELECT COUNT(*)
            FROM bookmarks
            INNER JOIN posts ON posts.id = bookmarks.post_id
            WHERE bookmarks.topic_id = topic_users.topic_id
            AND bookmarks.user_id = topic_users.user_id
            AND posts.deleted_at IS NULL
        ) = 0 #{topic_id.present? ? "AND topic_users.topic_id = :topic_id" : ""}
      SQL
    end
  end
end
