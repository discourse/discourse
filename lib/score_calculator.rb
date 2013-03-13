class ScoreCalculator

  def self.default_score_weights
    {
      reply_count: 5,
      like_count: 15,
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

    # Update the best of flag
    exec_sql "
      UPDATE topics SET has_best_of =
        CASE
          WHEN like_count >= :likes_required AND
          posts_count >= :posts_required AND
            EXISTS(SELECT * FROM posts AS p
                    WHERE p.topic_id = topics.id
                      AND p.score >= :score_required) THEN true
        ELSE false
        END",
      likes_required: SiteSetting.best_of_likes_required,
      posts_required: SiteSetting.best_of_posts_required,
      score_required: SiteSetting.best_of_score_threshold

  end


  private

    def exec_sql(sql, params)
      ActiveRecord::Base.exec_sql(sql, params)
    end

    # Generate a SQL statement to update the scores of all posts
    def post_score_sql
      "UPDATE posts SET score = ".tap do |sql|
        components = []
        @weightings.keys.each do |k|
          components << "COALESCE(#{k.to_s}, 0) * :#{k.to_s}"
        end
        sql << components.join(" + ")
      end
    end
end
