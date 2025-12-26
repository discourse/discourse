# frozen_string_literal: true

module Jobs
  class SyncTopicUserBookmarked < ::Jobs::Base
    def execute(args = {})
      raise Discourse::InvalidParameters.new(:topic_id) if args[:topic_id].blank?

      DB.exec(<<~SQL, topic_id: args[:topic_id])
        UPDATE topic_users tu
        SET bookmarked = computed.has_bookmark
        FROM (
          SELECT tu2.id, EXISTS (
            SELECT 1
            FROM bookmarks b
            LEFT JOIN posts p ON p.id = b.bookmarkable_id AND b.bookmarkable_type = 'Post'
            WHERE b.user_id = tu2.user_id
            AND (
                 (b.bookmarkable_type = 'Topic' AND b.bookmarkable_id = tu2.topic_id)
              OR (b.bookmarkable_type = 'Post' AND p.topic_id = tu2.topic_id AND p.deleted_at IS NULL)
            )
          ) AS has_bookmark
          FROM topic_users tu2
          WHERE tu2.topic_id = :topic_id
        ) computed
        WHERE tu.id = computed.id
        AND tu.bookmarked IS DISTINCT FROM computed.has_bookmark
      SQL
    end
  end
end
