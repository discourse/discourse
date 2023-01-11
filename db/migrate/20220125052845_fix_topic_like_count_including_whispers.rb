# frozen_string_literal: true

class FixTopicLikeCountIncludingWhispers < ActiveRecord::Migration[6.0]
  def up
    whisper_post_type = 4

    DB.exec(<<~SQL)
      UPDATE topics SET like_count = tbl.like_count
      FROM (
        SELECT topic_id, SUM(like_count) like_count
        FROM posts
        WHERE deleted_at IS NULL
        AND post_type <> #{whisper_post_type}
        GROUP BY topic_id
      ) AS tbl
      WHERE topics.id = tbl.topic_id
        AND topics.like_count <> tbl.like_count
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
