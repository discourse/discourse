# frozen_string_literal: true

class TopicHotScore < ActiveRecord::Base
  belongs_to :topic

  DEFAULT_BATCH_SIZE = 1000

  def self.update_scores(max = DEFAULT_BATCH_SIZE)
    # score is
    # (total likes - 1) / (age in hours + 2) ^ gravity

    # 1. insert a new record if one does not exist (up to batch size)
    # 2. update recently created (up to batch size)
    # 3. update all top scoring topics (up to batch size)

    now = Time.zone.now

    args = {
      now: now,
      gravity: SiteSetting.hot_topics_gravity,
      max: max,
      private_message: Archetype.private_message,
      recent_cutoff: now - SiteSetting.hot_topics_recent_days.days,
      regular: Post.types[:regular],
    }

    # insert up to BATCH_SIZE records that are missing from table
    DB.exec(<<~SQL, args)
      INSERT INTO topic_hot_scores (
        topic_id,
        score,
        recent_likes,
        recent_posters,
        created_at,
        updated_at
      )
      SELECT
        topics.id,
        0.0,
        0,
        0,
        :now,
        :now

      FROM topics
      LEFT OUTER JOIN topic_hot_scores ON topic_hot_scores.topic_id = topics.id
      WHERE topic_hot_scores.topic_id IS NULL
        AND topics.deleted_at IS NULL
        AND topics.archetype <> :private_message
        AND topics.created_at <= :now
      ORDER BY
        CASE WHEN topics.pinned_at IS NOT NULL THEN 0 ELSE 1 END ASC,
        topics.bumped_at desc
      LIMIT :max
    SQL

    # update recent counts for batch
    DB.exec(<<~SQL, args)
      UPDATE topic_hot_scores thsOrig
      SET
          recent_likes = COALESCE(new_values.likes_count, 0),
          recent_posters = COALESCE(new_values.unique_participants, 0),
          recent_first_bumped_at = COALESCE(new_values.first_bumped_at, ths.recent_first_bumped_at)
      FROM
        topic_hot_scores ths
        LEFT OUTER JOIN
        (
          SELECT
              t.id AS topic_id,
              COUNT(DISTINCT p.user_id) AS unique_participants,
              (
                SELECT COUNT(distinct pa.user_id)
                FROM post_actions pa
                JOIN posts p2 ON p2.id = pa.post_id
                WHERE p2.topic_id = t.id
                  AND p2.post_type = :regular
                  AND p2.deleted_at IS NULL
                  AND p2.user_deleted = false
                  AND pa.post_action_type_id = 2 -- action_type for 'like'
                  AND pa.created_at >= :recent_cutoff
                  AND pa.deleted_at IS NULL
              ) AS likes_count,
              MIN(p.created_at) AS first_bumped_at
          FROM
              topics t
          JOIN
              posts p ON t.id = p.topic_id
          WHERE
              p.created_at >= :recent_cutoff
              AND t.archetype <> 'private_message'
              AND t.deleted_at IS NULL
              AND p.deleted_at IS NULL
              AND p.user_deleted = false
              AND t.created_at <= :now
              AND t.bumped_at >= :recent_cutoff
              AND p.created_at < :now
              AND p.created_at >= :recent_cutoff
              AND p.post_type = :regular
          GROUP BY
              t.id
        ) AS new_values
      ON ths.topic_id = new_values.topic_id

      WHERE thsOrig.topic_id = ths.topic_id
    SQL

    # we may end up update 2x batch size, this is ok
    # we need to update 1 batch of high scoring topics
    # we need to update a second batch of recently bumped topics
    sql = <<~SQL
      WITH topic_ids AS (
        SELECT topic_id FROM (
          SELECT th3.topic_id FROM topic_hot_scores th3
          JOIN topics t3 on t3.id = th3.topic_id
          ORDER BY t3.bumped_at DESC
          LIMIT :max
        ) Y

        UNION ALL

        SELECT topic_id FROM (
          SELECT th2.topic_id FROM topic_hot_scores th2
          ORDER BY th2.score DESC, th2.recent_first_bumped_at DESC NULLS LAST
          LIMIT :max
        ) X
      )
      UPDATE topic_hot_scores ths
      SET score = (
        CASE WHEN topics.created_at > :recent_cutoff
          THEN ths.recent_likes ELSE topics.like_count END
        ) /
        (EXTRACT(EPOCH FROM (:now - topics.created_at)) / 3600 + 2) ^ :gravity
 +
        CASE WHEN ths.recent_first_bumped_at IS NULL THEN 0 ELSE
          (ths.recent_likes + ths.recent_posters - 1) /
          (EXTRACT(EPOCH FROM (:now - recent_first_bumped_at)) / 3600 + 2) ^ :gravity
        END
        ,
        updated_at = :now

      FROM topics
      WHERE topics.id IN (
        SELECT topic_id FROM topic_ids
      ) AND ths.topic_id = topics.id AND topics.created_at <= :now
    SQL

    DB.exec(sql, args)

    DiscourseEvent.trigger(:topic_hot_scores_updated)
  end
end

# == Schema Information
#
# Table name: topic_hot_scores
#
#  id                     :bigint           not null, primary key
#  topic_id               :integer          not null
#  score                  :float            default(0.0), not null
#  recent_likes           :integer          default(0), not null
#  recent_posters         :integer          default(0), not null
#  recent_first_bumped_at :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_topic_hot_scores_on_score_and_topic_id  (score,topic_id) UNIQUE
#  index_topic_hot_scores_on_topic_id            (topic_id) UNIQUE
#
