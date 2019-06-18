# frozen_string_literal: true

class CorrectPostNumberIndex < ActiveRecord::Migration[4.2]
  def change

    begin
      a = execute <<SQL
      UPDATE posts SET post_number = post_number + 1
      WHERE id IN (
        SELECT p1.id
        FROM posts p1
        JOIN
        (
          SELECT post_number, topic_id, min(id) min_id
          FROM posts
          GROUP BY post_number, topic_id
          HAVING COUNT(*) > 1
        ) pp ON p1.topic_id = pp.topic_id AND
                p1.post_number >= pp.post_number AND
                p1.id <> pp.min_id
      )
SQL
    end until a.cmdtuples == 0

    remove_index :posts, [:topic_id, :post_number]
    add_index :posts, [:topic_id, :post_number], unique: true
  end
end
