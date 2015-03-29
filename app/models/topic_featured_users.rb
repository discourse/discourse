class TopicFeaturedUsers
  attr_reader :topic

  def initialize(topic)
    @topic = topic
  end

  def self.count
    4
  end

  # Chooses which topic users to feature
  def choose(args={})
    clear
    update keys(args)
    update_participant_count
    topic.save
  end

  def user_ids
    [topic.featured_user1_id,
     topic.featured_user2_id,
     topic.featured_user3_id,
     topic.featured_user4_id].uniq.compact
  end

  def self.ensure_consistency!

    sql = <<SQL

WITH cte as (
    SELECT
        t.id, p.user_id,
        ROW_NUMBER() OVER(PARTITION BY t.id ORDER BY COUNT(*) DESC) as rank
    FROM topics t
    JOIN posts p ON p.topic_id = t.id
    WHERE p.deleted_at IS NULL AND NOT p.hidden AND p.user_id <> t.user_id AND
          p.user_id <> t.last_post_user_id
    GROUP BY t.id, p.user_id
)

UPDATE topics tt
SET
  featured_user1_id = featured_user1,
  featured_user2_id = featured_user2,
  featured_user3_id = featured_user3,
  featured_user4_id = featured_user4
FROM (
  SELECT
      c.id,
      MAX(case when c.rank = 1 then c.user_id end) featured_user1,
      MAX(case when c.rank = 2 then c.user_id end) featured_user2,
      MAX(case when c.rank = 3 then c.user_id end) featured_user3,
      MAX(case when c.rank = 4 then c.user_id end) featured_user4
  FROM cte as c
  WHERE c.rank <= 4
  GROUP BY c.id
) x
WHERE x.id = tt.id AND
(
  COALESCE(featured_user1_id,-99) <> COALESCE(featured_user1,-99) OR
  COALESCE(featured_user2_id,-99) <> COALESCE(featured_user2,-99) OR
  COALESCE(featured_user3_id,-99) <> COALESCE(featured_user3,-99) OR
  COALESCE(featured_user4_id,-99) <> COALESCE(featured_user4,-99)
)
SQL

    Topic.exec_sql(sql)
  end

  private

    def keys(args)
      # Don't include the OP or the last poster
      to_feature = topic.posts.where('user_id NOT IN (?, ?)', topic.user_id, topic.last_post_user_id)

      # Exclude a given post if supplied (in the case of deletes)
      to_feature = to_feature.where("id <> ?", args[:except_post_id]) if args[:except_post_id].present?

      # Assign the featured_user{x} columns
      to_feature.group(:user_id).order('count_all desc').limit(TopicFeaturedUsers.count).count.keys
    end

    def clear
      TopicFeaturedUsers.count.times do |i|
        topic.send("featured_user#{i+1}_id=", nil)
      end
    end

    def update(user_keys)
      user_keys.each_with_index do |user_id, i|
        topic.send("featured_user#{i+1}_id=", user_id)
      end
    end

    def update_participant_count
      topic.participant_count = topic.posts.count('distinct user_id')
    end
end
