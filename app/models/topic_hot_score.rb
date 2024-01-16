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

    args = {
      now: Time.zone.now,
      gravity: SiteSetting.hot_topics_gravity,
      max: max,
      private_message: Archetype.private_message,
    }

    # insert up to BATCH_SIZE records that are missing
    DB.exec(<<~SQL, args)
      INSERT INTO topic_hot_scores (topic_id, score, created_at, updated_at)
      SELECT
        topics.id,
        (topics.like_count - 1) /
        (EXTRACT(EPOCH FROM (:now - topics.created_at)) / 3600 + 2) ^ :gravity,
        :now,
        :now

      FROM topics
      LEFT OUTER JOIN topic_hot_scores ON topic_hot_scores.topic_id = topics.id
      WHERE topic_hot_scores.topic_id IS NULL
        AND topics.deleted_at IS NULL
        AND topics.archetype <> :private_message
        AND topics.created_at <= :now
      ORDER BY topics.created_at desc
      LIMIT :max
    SQL

    # update up to BATCH_SIZE records that are out of date based on age
    # we need an extra index for this
    DB.exec(<<~SQL, args)
      UPDATE topic_hot_scores
      SET score = (topics.like_count - 1) /
        (EXTRACT(EPOCH FROM (:now - topics.created_at)) / 3600 + 2) ^ :gravity,
        updated_at = :now
      FROM topics
      WHERE topics.id IN (
        SELECT * FROM (
          SELECT topic_hot_scores.topic_id
          FROM topic_hot_scores
          JOIN topics t2 ON t2.id = topic_hot_scores.topic_id
          WHERE topics.deleted_at IS NULL
          AND topics.archetype <> :private_message
          AND topics.created_at <= :now
          ORDER BY topics.created_at desc
          LIMIT :max
        ) AS t
        UNION ALL
        SELECT * FROM (
          SELECT topic_hot_scores.topic_id
          FROM topic_hot_scores
          ORDER BY topic_hot_scores.score desc
          LIMIT :max
        ) AS t1
      ) AND topic_hot_scores.topic_id = topics.id
    SQL
  end
end

# == Schema Information
#
# Table name: topic_hot_scores
#
#  id         :bigint           not null, primary key
#  topic_id   :integer          not null
#  score      :float            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_topic_hot_scores_on_score_and_topic_id  (score,topic_id) UNIQUE
#  index_topic_hot_scores_on_topic_id            (topic_id) UNIQUE
#
