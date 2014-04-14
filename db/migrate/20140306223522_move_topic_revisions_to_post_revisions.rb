class MoveTopicRevisionsToPostRevisions < ActiveRecord::Migration
  def up
    execute <<SQL

    INSERT INTO post_revisions(user_id, post_id, modifications, number, created_at, updated_at)
    SELECT tr.user_id, p.id, tr.modifications, tr.number, tr.created_at, tr.updated_at
    FROM topic_revisions tr
    JOIN topics t ON t.id = tr.topic_id
    JOIN posts p ON p.topic_id = t.id AND p.post_number = 1

SQL

   execute <<SQL

   UPDATE post_revisions r SET number = 2 + (
    SELECT COUNT(*) FROM post_revisions r2
    WHERE r2.post_id = r.post_id AND r2.created_at < r.created_at
   )

SQL

    execute <<SQL

    UPDATE posts p SET version = 1 + (
      SELECT COUNT(*) FROM post_revisions r
      WHERE r.post_id = p.id
    )

SQL

    execute <<SQL

    DROP TABLE topic_revisions

SQL

  end

  def down
    # strictly, we could reverse this, but not implemented
    raise ActiveRecord::IrreversibleMigration
  end
end
