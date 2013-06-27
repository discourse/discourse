class AddLikeScoreToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :like_score, :integer, default: 0, null: false

    execute "UPDATE posts p
              set like_score = x.like_score
              FROM (SELECT pa.post_id,
                            SUM(CASE
                                 WHEN u.admin OR u.moderator THEN 3
                                 ELSE 1
                                END) AS like_score
                    FROM post_actions AS pa
                    INNER JOIN users AS u ON u.id = pa.user_id
                    GROUP BY pa.post_id) AS x
              WHERE x.post_id = p.id"
  end
end


