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
      max_hot_topics = 200          # how many hot topics we want
      hot_percentile = 0.2          # What percentile of topics we consider good
      older_percentage = 0.2        # how many old topics we want as a percentage
      new_days = 21                 # how many days old we consider old
      no_old_in_first_x_rows = 8    # don't show old results in the first x rows

      # Include all sticky uncategorized on Hot
      exec_sql("INSERT INTO hot_topics (topic_id,
                                        random_bias,
                                        random_multiplier,
                                        days_ago_bias,
                                        days_ago_multiplier,
                                        score,
                                        hot_topic_type)
                SELECT t.id,
                       calc.random_bias,
                       1.0,
                       0,
                       1.0,
                       calc.random_bias,
                       1
                FROM topics AS t
                INNER JOIN (SELECT id, RANDOM() as random_bias
                            FROM topics) AS calc ON calc.id = t.id
                WHERE t.deleted_at IS NULL
                  AND t.visible
                  AND (NOT t.archived)
                  AND t.pinned_at IS NOT NULL
                  AND t.category_id IS NULL")

      # Include high percentile recent topics
      inserted_count = exec_sql("INSERT INTO hot_topics (topic_id,
                                                         category_id,
                                                         random_bias,
                                                         random_multiplier,
                                                         days_ago_bias,
                                                         days_ago_multiplier,
                                                         score,
                                                         hot_topic_type)
                                  SELECT t.id,
                                         t.category_id,
                                         calc.random_bias,
                                         0.05,
                                         calc.days_ago_bias,
                                         0.95,
                                         (calc.random_bias * 0.05) + (days_ago_bias * 0.95),
                                         2
                                  FROM topics AS t
                                  INNER JOIN (SELECT id,
                                                     RANDOM() as random_bias,
                                                     ((1.0 - (EXTRACT(EPOCH FROM CURRENT_TIMESTAMP-created_at)/86400) / :days_ago) * 0.95) AS days_ago_bias
                                              FROM topics) AS calc ON calc.id = t.id
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

      max_old_score = 1.0

      # Finding the highest score in the first x rows
      if HotTopic.count > no_old_in_first_x_rows
        max_old_score = HotTopic.order('score desc').limit(no_old_in_first_x_rows).last.score
      end

      # Add a sprinkling of random older topics
      exec_sql("INSERT INTO hot_topics (topic_id,
                                       category_id,
                                       random_bias,
                                       random_multiplier,
                                       days_ago_bias,
                                       days_ago_multiplier,
                                       score,
                                       hot_topic_type)
                SELECT t.id,
                       t.category_id,
                       calc.random_bias,
                       :max_old_score,
                       0,
                       1.0,
                       calc.random_bias * :max_old_score,
                       3
                FROM topics AS t
                INNER JOIN (SELECT id, RANDOM() as random_bias
                            FROM topics) AS calc ON calc.id = t.id
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
                days_ago: new_days,
                max_old_score: max_old_score)
    end
  end

end

# == Schema Information
#
# Table name: hot_topics
#
#  id                  :integer          not null, primary key
#  topic_id            :integer          not null
#  category_id         :integer
#  score               :float            not null
#  random_bias         :float
#  random_multiplier   :float
#  days_ago_bias       :float
#  days_ago_multiplier :float
#  hot_topic_type      :integer
#
# Indexes
#
#  index_hot_topics_on_score     (score)
#  index_hot_topics_on_topic_id  (topic_id) UNIQUE
#

