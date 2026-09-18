# frozen_string_literal: true

class ScoreCalculator
  TOPIC_BATCH_SIZE = 1000

  def self.default_score_weights
    { reply_count: 5, like_score: 15, incoming_link_count: 5, bookmark_count: 2, reads: 0.2 }
  end

  def initialize(weightings = nil)
    @weightings = weightings || ScoreCalculator.default_score_weights
  end

  # Calculate the score for all posts based on the weightings
  def calculate(opts = nil)
    topics = Topic.unscoped
    if opts
      topics = topics.where("bumped_at > ?", opts[:min_topic_age]) if opts[:min_topic_age]
      topics = topics.where("posts_count < ?", opts[:max_topic_length]) if opts[:max_topic_length]
    end

    # Keep each topic's posts together so ranks include the entire partition.
    topics.in_batches(of: TOPIC_BATCH_SIZE) do |batch|
      topic_ids = batch.pluck(:id)
      update_posts_score(topic_ids)
      update_posts_rank(topic_ids)
      update_topics_rank(topic_ids)
    end
  end

  private

  def update_posts_score(topic_ids)
    components = @weightings.keys.map { |k| "COALESCE(posts.#{k}, 0) * :#{k}" }.join(" + ")

    DB.exec(<<~SQL, @weightings.merge(topic_ids: topic_ids))
      UPDATE posts
      SET score = #{components}
      WHERE topic_id IN (:topic_ids)
        AND (score IS NULL OR score <> #{components})
    SQL
  end

  def update_posts_rank(topic_ids)
    DB.exec(<<~SQL, topic_ids: topic_ids)
      UPDATE posts
      SET percent_rank = ranked.percent_rank
      FROM (
        SELECT id, percent_rank() OVER (PARTITION BY topic_id ORDER BY score DESC) AS percent_rank
        FROM posts
        WHERE topic_id IN (:topic_ids)
      ) AS ranked
      WHERE posts.id = ranked.id
        AND (posts.percent_rank IS NULL OR posts.percent_rank <> ranked.percent_rank)
    SQL
  end

  def update_topics_rank(topic_ids)
    builder = DB.build <<~SQL
      UPDATE topics AS topics
      SET has_summary = (topics.like_count >= :likes_required AND
                         topics.posts_count >= :posts_required AND
                         x.max_score >= :score_required),
          score = x.avg_score
      FROM (SELECT p.topic_id,
                   MAX(p.score) AS max_score,
                   AVG(p.score) AS avg_score
            FROM posts AS p
            WHERE p.topic_id IN (:topic_ids)
            GROUP BY p.topic_id) AS x
            /*where*/
    SQL

    defaults = {
      topic_ids: topic_ids,
      likes_required: SiteSetting.summary_likes_required,
      posts_required: SiteSetting.summary_posts_required,
      score_required: SiteSetting.summary_score_threshold,
    }

    builder.where(<<~SQL, defaults)
      x.topic_id = topics.id AND
      (
        (topics.score <> x.avg_score OR topics.score IS NULL) OR
        (topics.has_summary IS NULL OR topics.has_summary <> (
          topics.like_count >= :likes_required AND
          topics.posts_count >= :posts_required AND
          x.max_score >= :score_required
        ))
      )
    SQL

    builder.exec
  end
end
