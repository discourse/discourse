class HotTopic < ActiveRecord::Base

  belongs_to :topic
  belongs_to :category

  # Here's the current idea behind the implementaiton of hot: random can produce good results!
  # Hot is currently made up of a random selection of high percentile topics. It includes mostly
  # new topics, but also some old ones for variety.
  def self.refresh!
    transaction do
      exec_sql "DELETE FROM hot_topics"

      # TODO, move these to site settings once we're sure this is how we want to figure out hot
      max_hot_topics = 200        # how many hot topics we want
      hot_percentile = 0.2        # What percentile of topics we consider good
      older_percentage = 0.2      # how many old topics we want as a percentage
      new_days = 21               # how many days old we consider old


      # Include all sticky uncategorized on Hot
      exec_sql("INSERT INTO hot_topics (topic_id, score)
                SELECT t.id, RANDOM()
                FROM topics AS t
                WHERE t.deleted_at IS NULL
                  AND t.visible
                  AND (NOT t.archived)
                  AND t.pinned_at IS NOT NULL
                  AND t.category_id IS NULL")

      # Include high percentile recent topics
      exec_sql("INSERT INTO hot_topics (topic_id, category_id, score)
                SELECT t.id,
                       t.category_id,
                       ((1.0 - (EXTRACT(EPOCH FROM CURRENT_TIMESTAMP-t.created_at)/86400) / :days_ago) * 0.95) + (RANDOM() * 0.05)
                FROM topics AS t
                WHERE t.deleted_at IS NULL
                  AND t.visible
                  AND (NOT t.closed)
                  AND (NOT t.archived)
                  AND t.pinned_at IS NULL
                  AND t.archetype <> :private_message
                  AND created_at >= (CURRENT_TIMESTAMP - INTERVAL ':days_ago' DAY)
                  AND t.percent_rank < :hot_percentile
                  AND NOT EXISTS(SELECT * FROM hot_topics AS ht2 WHERE ht2.topic_id = t.id)
                LIMIT :limit",
                hot_percentile: hot_percentile,
                limit: ((1.0 - older_percentage) * max_hot_topics).round,
                private_message: Archetype::private_message,
                days_ago: new_days)

      # Add a sprinkling of random older topics
      exec_sql("INSERT INTO hot_topics (topic_id, category_id, score)
                SELECT t.id,
                       t.category_id,
                       RANDOM()
                FROM topics AS t
                WHERE t.deleted_at IS NULL
                  AND t.visible
                  AND (NOT t.closed)
                  AND (NOT t.archived)
                  AND t.pinned_at IS NULL
                  AND t.archetype <> :private_message
                  AND created_at < (CURRENT_TIMESTAMP - INTERVAL ':days_ago' DAY)
                  AND t.percent_rank < :hot_percentile
                  AND NOT EXISTS(SELECT * FROM hot_topics AS ht2 WHERE ht2.topic_id = t.id)
                LIMIT :limit",
                hot_percentile: hot_percentile,
                limit: (older_percentage * max_hot_topics).round,
                private_message: Archetype::private_message,
                days_ago: new_days)
    end
  end

end
