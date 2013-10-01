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
  def calculate

    # First update the scores of the posts
    exec_sql(post_score_sql, @weightings)

    # Update the percent rankings of the posts
    exec_sql("UPDATE posts SET percent_rank = x.percent_rank
              FROM (SELECT id, percent_rank()
                    OVER (PARTITION BY topic_id ORDER BY SCORE DESC) as percent_rank
                    FROM posts) AS x
              WHERE x.id = posts.id AND
               (posts.percent_rank IS NULL OR x.percent_rank <> posts.percent_rank)")


    # Update the topics
    exec_sql "UPDATE topics AS t
              SET has_best_of = (t.like_count >= :likes_required AND
                                 t.posts_count >= :posts_required AND
                                 x.max_score >= :score_required),
                  score = x.avg_score
              FROM (SELECT p.topic_id,
                           MAX(p.score) AS max_score,
                           AVG(p.score) AS avg_score
                    FROM posts AS p
                    GROUP BY p.topic_id) AS x
              WHERE x.topic_id = t.id AND
                        (
                          (t.score <> x.avg_score OR t.score IS NULL) OR
                          (t.has_best_of IS NULL OR t.has_best_of <> (
                            t.like_count >= :likes_required AND
                            t.posts_count >= :posts_required AND
                            x.max_score >= :score_required
                          ))
                        )
  ",
              likes_required: SiteSetting.best_of_likes_required,
              posts_required: SiteSetting.best_of_posts_required,
              score_required: SiteSetting.best_of_score_threshold

    # Update percentage rank of topics
    exec_sql("UPDATE topics SET percent_rank = x.percent_rank
          FROM (SELECT id, percent_rank()
                OVER (ORDER BY SCORE DESC) as percent_rank
                FROM topics) AS x
          WHERE x.id = topics.id AND (topics.percent_rank <> x.percent_rank OR topics.percent_rank IS NULL)")
  end


  private

    def exec_sql(sql, params=nil)
      ActiveRecord::Base.exec_sql(sql, params)
    end

    # Generate a SQL statement to update the scores of all posts
    def post_score_sql
      components = []
      @weightings.keys.each { |k| components << "COALESCE(#{k.to_s}, 0) * :#{k.to_s}" }
      components = components.join(" + ")

      "UPDATE posts SET score = x.score
       FROM (SELECT id, #{components} as score FROM posts) AS x
       WHERE x.id = posts.id AND (posts.score IS NULL OR x.score <> posts.score)"
    end
end
