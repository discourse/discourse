class ScoreCalculator

  def self.default_score_weights
    {
      reply_count: 5,
      like_score: 15,
      incoming_link_count: 5,
      bookmark_count: 2,
      avg_time: 0.05,
      reads: 0.2
    }
  end

  def initialize(weightings=nil)
    @weightings = weightings || ScoreCalculator.default_score_weights
  end

  # Calculate the score for all posts based on the weightings
  def calculate(min_topic_age=nil)

    update_posts_score(min_topic_age)

    update_posts_rank(min_topic_age)

    update_topics_rank(min_topic_age)

    update_topics_percent_rank(min_topic_age)

  end


  private

  def update_posts_score(min_topic_age)
    components = []
    @weightings.each_key { |k| components << "COALESCE(#{k}, 0) * :#{k}" }
    components = components.join(" + ")

    builder = SqlBuilder.new(
      "UPDATE posts SET score = x.score
       FROM (SELECT id, #{components} as score FROM posts) AS x
       /*where*/"

    )

    builder.where("x.id = posts.id
                  AND (posts.score IS NULL OR x.score <> posts.score)", @weightings)

    filter_topics(builder, min_topic_age)

    builder.exec
  end

  def update_posts_rank(min_topic_age)

    builder = SqlBuilder.new("UPDATE posts SET percent_rank = x.percent_rank
              FROM (SELECT id, percent_rank()
                    OVER (PARTITION BY topic_id ORDER BY SCORE DESC) as percent_rank
                    FROM posts) AS x
                   /*where*/")

    builder.where("x.id = posts.id AND
               (posts.percent_rank IS NULL OR x.percent_rank <> posts.percent_rank)")


    filter_topics(builder, min_topic_age)

    builder.exec
  end

  def update_topics_rank(min_topic_age)
    builder = SqlBuilder.new("UPDATE topics AS t
              SET has_summary = (t.like_count >= :likes_required AND
                                 t.posts_count >= :posts_required AND
                                 x.max_score >= :score_required),
                  score = x.avg_score
              FROM (SELECT p.topic_id,
                           MAX(p.score) AS max_score,
                           AVG(p.score) AS avg_score
                    FROM posts AS p
                    GROUP BY p.topic_id) AS x
                    /*where*/")

    builder.where("x.topic_id = t.id AND
                        (
                          (t.score <> x.avg_score OR t.score IS NULL) OR
                          (t.has_summary IS NULL OR t.has_summary <> (
                            t.like_count >= :likes_required AND
                            t.posts_count >= :posts_required AND
                            x.max_score >= :score_required
                          ))
                        )
  ",
              likes_required: SiteSetting.summary_likes_required,
              posts_required: SiteSetting.summary_posts_required,
              score_required: SiteSetting.summary_score_threshold)

    if min_topic_age
      builder.where("t.bumped_at > :bumped_at ",
                   bumped_at: min_topic_age)
    end

    builder.exec
  end

  def update_topics_percent_rank(min_topic_age)

    builder = SqlBuilder.new("UPDATE topics SET percent_rank = x.percent_rank
          FROM (SELECT id, percent_rank()
                OVER (ORDER BY SCORE DESC) as percent_rank
                FROM topics) AS x
                /*where*/")

    builder.where("x.id = topics.id AND (topics.percent_rank <> x.percent_rank OR topics.percent_rank IS NULL)")


    if min_topic_age
      builder.where("topics.bumped_at > :bumped_at ",
                   bumped_at: min_topic_age)
    end


    builder.exec
  end


  def filter_topics(builder, min_topic_age)
    if min_topic_age
      builder.where('posts.topic_id IN
                    (SELECT id FROM topics WHERE bumped_at > :bumped_at)',
                   bumped_at: min_topic_age)
    end

    builder
  end

end
