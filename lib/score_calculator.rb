# frozen_string_literal: true

class ScoreCalculator

  def self.default_score_weights
    {
      reply_count: 5,
      like_score: 15,
      incoming_link_count: 5,
      bookmark_count: 2,
      reads: 0.2
    }
  end

  def initialize(weightings = nil)
    @weightings = weightings || ScoreCalculator.default_score_weights
  end

  # Calculate the score for all posts based on the weightings
  def calculate(opts = nil)
    update_posts_score(opts)
    update_posts_rank(opts)
    update_topics_rank(opts)
  end

  private

  def update_posts_score(opts)
    limit = 20000

    components = []
    @weightings.each_key { |k| components << "COALESCE(posts.#{k}, 0) * :#{k}" }
    components = components.join(" + ")

    builder = DB.build <<SQL
       UPDATE posts p
        SET score = x.score
       FROM (
        SELECT posts.id, #{components} as score FROM posts
        join topics on posts.topic_id = topics.id
        /*where*/
        limit #{limit}
       ) AS x
       WHERE x.id = p.id
SQL

    builder.where("posts.score IS NULL OR posts.score <> #{components}", @weightings)

    filter_topics(builder, opts)

    while builder.exec == limit
    end
  end

  def update_posts_rank(opts)
    limit = 20000

    builder = DB.build <<~SQL
      UPDATE posts
      SET percent_rank = X.percent_rank
      FROM (
        SELECT posts.id, Y.percent_rank
        FROM posts
        JOIN (
          SELECT id, percent_rank()
                       OVER (PARTITION BY topic_id ORDER BY SCORE DESC) as percent_rank
          FROM posts
         ) Y ON Y.id = posts.id
         JOIN topics ON posts.topic_id = topics.id
        /*where*/
        LIMIT #{limit}
      ) AS X
      WHERE posts.id = X.id
    SQL

    builder.where("posts.percent_rank IS NULL OR Y.percent_rank <> posts.percent_rank")

    filter_topics(builder, opts)

    while builder.exec == limit
    end

  end

  def update_topics_rank(opts)
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
            GROUP BY p.topic_id) AS x
            /*where*/
    SQL

    defaults = {
      likes_required: SiteSetting.summary_likes_required,
      posts_required: SiteSetting.summary_posts_required,
      score_required: SiteSetting.summary_score_threshold
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

    filter_topics(builder, opts)

    builder.exec
  end

  def filter_topics(builder, opts)
    return builder unless opts

    if min_topic_age = opts[:min_topic_age]
      builder.where("topics.bumped_at > :bumped_at ",
                 bumped_at: min_topic_age)
    end
    if max_topic_length = opts[:max_topic_length]
      builder.where("topics.posts_count < :max_topic_length",
                 max_topic_length: max_topic_length)
    end

    builder
  end

end
