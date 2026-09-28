# frozen_string_literal: true

module Migrations
  module Importer
    module Steps
      class TopicStatistics < Step
        TOPIC_BATCH_SIZE = 1_000

        depends_on :posts

        def execute
          super

          each_imported_topic_id_batch { |topic_ids| update_topic_statistics(topic_ids) }
        end

        private

        def each_imported_topic_id_batch
          topic_ids = []

          @intermediate_db.query(<<~SQL, MappingType::POSTS, MappingType::TOPICS) do |row|
            SELECT DISTINCT mapped_topic.discourse_id
            FROM posts
                 JOIN mapped.ids mapped_post
                   ON mapped_post.original_id = posts.original_id AND mapped_post.type = ?
                 JOIN mapped.ids mapped_topic
                   ON mapped_topic.original_id = posts.topic_id AND mapped_topic.type = ?
            ORDER BY mapped_topic.discourse_id
          SQL
            topic_ids << row[:discourse_id]
            next if topic_ids.size < TOPIC_BATCH_SIZE

            yield topic_ids
            topic_ids = []
          end

          yield topic_ids if topic_ids.any?
        end

        def update_topic_statistics(topic_ids)
          DB.exec(<<~SQL, topic_ids:)
            WITH public_posts AS (
              SELECT posts.topic_id,
                     MAX(posts.post_number) AS highest_post_number,
                     COUNT(*) AS posts_count,
                     MAX(posts.created_at) AS last_posted_at
              FROM posts
              WHERE posts.topic_id IN (:topic_ids)
                AND posts.deleted_at IS NULL
                AND #{Topic.public_post_types_sql}
              GROUP BY posts.topic_id
            ),
            staff_posts AS (
              SELECT posts.topic_id,
                     MAX(posts.post_number) AS highest_staff_post_number
              FROM posts
              WHERE posts.topic_id IN (:topic_ids)
                AND posts.deleted_at IS NULL
                AND #{Topic.staff_post_types_sql}
              GROUP BY posts.topic_id
            ),
            last_posters AS (
              SELECT DISTINCT ON (posts.topic_id) posts.topic_id, posts.user_id
              FROM posts
              WHERE posts.topic_id IN (:topic_ids)
                AND posts.deleted_at IS NULL
                AND NOT posts.hidden
                AND #{Topic.public_post_types_sql}
              ORDER BY posts.topic_id, posts.post_number DESC
            )
            UPDATE topics
            SET highest_post_number = public_posts.highest_post_number,
                highest_staff_post_number =
                  COALESCE(staff_posts.highest_staff_post_number, public_posts.highest_post_number),
                posts_count = public_posts.posts_count,
                last_posted_at = public_posts.last_posted_at,
                bumped_at = COALESCE(public_posts.last_posted_at, topics.bumped_at),
                last_post_user_id = COALESCE(last_posters.user_id, topics.last_post_user_id)
            FROM public_posts
                 LEFT JOIN staff_posts ON staff_posts.topic_id = public_posts.topic_id
                 LEFT JOIN last_posters ON last_posters.topic_id = public_posts.topic_id
            WHERE topics.id = public_posts.topic_id
          SQL
        end
      end
    end
  end
end
