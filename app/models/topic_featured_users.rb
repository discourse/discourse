# frozen_string_literal: true

class TopicFeaturedUsers
  FREQUENT_POSTER_COUNT = 2

  attr_reader :topic

  def initialize(topic)
    @topic = topic
  end

  def self.count
    4
  end

  def self.recent_poster_count
    count - FREQUENT_POSTER_COUNT
  end

  # Chooses which topic users to feature
  def choose(args = {})
    self.class.ensure_consistency!(topic.id.to_i)
    update_participant_count
  end

  def user_ids
    slot_user_ids.uniq.compact
  end

  def recent_user_ids
    slot_user_ids.last(self.class.recent_poster_count).compact
  end

  def self.ensure_consistency!(topic_id = nil)
    filter = "#{"AND t.id = #{topic_id.to_i}" if topic_id}"
    filter2 = "#{"AND tt.id = #{topic_id.to_i}" if topic_id}"

    # The topic list shows up to five posters in this order: the OP, two frequent posters,
    # and two recent posters. Recent posters are excluded from frequent posters, and the OP
    # is excluded from both. The latest poster is handled separately and replaces a recent
    # poster unless the OP is the latest poster.

    sql = <<SQL

WITH poster_stats as (
    SELECT
        t.id,
        t.user_id as topic_user_id,
        t.last_post_user_id,
        p.user_id,
        COUNT(*) post_count,
        MAX(p.created_at) last_post_date,
        MAX(p.id) last_post_id,
        ROW_NUMBER() OVER(PARTITION BY t.id ORDER BY MAX(p.created_at) DESC, MAX(p.id) DESC) as recent_rank
    FROM topics t
    JOIN posts p ON p.topic_id = t.id
    WHERE p.deleted_at IS NULL AND
          NOT p.hidden AND
          p.post_type in (#{Topic.visible_post_types.join(",")}) AND
          p.user_id <> t.user_id AND
          p.user_id <> t.last_post_user_id
          #{filter}
    GROUP BY t.id, t.user_id, t.last_post_user_id, p.user_id
),

selected_recent_posters as (
  SELECT id, user_id, recent_rank + #{FREQUENT_POSTER_COUNT} as rank
  FROM poster_stats
  WHERE topic_user_id = last_post_user_id AND recent_rank <= #{recent_poster_count}

  UNION ALL

  SELECT id, user_id, recent_rank + #{FREQUENT_POSTER_COUNT} as rank
  FROM poster_stats
  WHERE topic_user_id <> last_post_user_id AND recent_rank <= #{recent_poster_count - 1}
),

selected_frequent_posters as (
  SELECT
    id,
    user_id,
    ROW_NUMBER() OVER(PARTITION BY id ORDER BY post_count DESC, last_post_date DESC, last_post_id DESC) as rank
  FROM poster_stats
  WHERE topic_user_id = last_post_user_id AND recent_rank > #{recent_poster_count}

  UNION ALL

  SELECT
    id,
    user_id,
    ROW_NUMBER() OVER(PARTITION BY id ORDER BY post_count DESC, last_post_date DESC, last_post_id DESC) as rank
  FROM poster_stats
  WHERE topic_user_id <> last_post_user_id AND recent_rank > #{recent_poster_count - 1}
),

selected_topic_posters as (
  SELECT id, user_id, rank
  FROM selected_frequent_posters
  WHERE rank <= #{FREQUENT_POSTER_COUNT}

  UNION ALL

  SELECT id, user_id, rank
  FROM selected_recent_posters
)

UPDATE topics tt
SET
  featured_user1_id = x.featured_user1,
  featured_user2_id = x.featured_user2,
  featured_user3_id = x.featured_user3,
  featured_user4_id = x.featured_user4
FROM topics AS tt2
LEFT OUTER JOIN (
  SELECT
      selected_topic_posters.id,
      MAX(case when selected_topic_posters.rank = 1 then selected_topic_posters.user_id end) featured_user1,
      MAX(case when selected_topic_posters.rank = 2 then selected_topic_posters.user_id end) featured_user2,
      MAX(case when selected_topic_posters.rank = 3 then selected_topic_posters.user_id end) featured_user3,
      MAX(case when selected_topic_posters.rank = 4 then selected_topic_posters.user_id end) featured_user4
  FROM selected_topic_posters
  GROUP BY selected_topic_posters.id
) x ON x.id = tt2.id
WHERE tt.id = tt2.id AND
(
  COALESCE(tt.featured_user1_id,-99) <> COALESCE(x.featured_user1,-99) OR
  COALESCE(tt.featured_user2_id,-99) <> COALESCE(x.featured_user2,-99) OR
  COALESCE(tt.featured_user3_id,-99) <> COALESCE(x.featured_user3,-99) OR
  COALESCE(tt.featured_user4_id,-99) <> COALESCE(x.featured_user4,-99)
)
#{filter2}
SQL

    DB.exec(sql)
  end

  private

  def slot_user_ids
    [
      topic.featured_user1_id,
      topic.featured_user2_id,
      topic.featured_user3_id,
      topic.featured_user4_id,
    ]
  end

  def update_participant_count
    DB.exec(<<~SQL, topic_id: topic.id)
      UPDATE topics
      SET participant_count = (
        SELECT COUNT(DISTINCT user_id)
        FROM posts
        WHERE topic_id = :topic_id
          AND NOT hidden
          AND post_type IN (#{Topic.visible_post_types.join(",")})
          AND deleted_at IS NULL
      )
      WHERE id = :topic_id
    SQL
  end
end
