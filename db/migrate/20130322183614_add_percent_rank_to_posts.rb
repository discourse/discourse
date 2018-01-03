class AddPercentRankToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :percent_rank, :float, default: 1.0

    execute "UPDATE posts SET percent_rank = x.percent_rank
              FROM (SELECT id, percent_rank()
                    OVER (PARTITION BY topic_id ORDER BY SCORE DESC)
                    FROM posts) AS x
              WHERE x.id = posts.id"

  end
end
