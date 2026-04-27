# frozen_string_literal: true

class RewriteAiArtifactToWebArtifactMarkup < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 1_000

  WHERE_CLAUSE = <<~SQL
    raw ~ 'class=["'']ai-artifact["'']'
    OR raw ~ 'data-ai-artifact-(id|version|height|autorun|seamless)'
    OR cooked ~ 'class=["'']ai-artifact["'']'
    OR cooked ~ 'data-ai-artifact-(id|version|height|autorun|seamless)'
  SQL

  UPDATE_SQL = <<~'SQL'
    WITH cte AS (
      SELECT id FROM posts
      WHERE %{where_clause}
      LIMIT :batch_size
      FOR UPDATE
    )
    UPDATE posts
    SET
      raw =
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            posts.raw,
            '(class=["''])ai-artifact(["''])',
            '\1web-artifact\2',
            'g'
          ),
          'data-ai-artifact-(id|version|height|autorun|seamless)',
          'data-web-artifact-\1',
          'g'
        ),
      cooked =
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            posts.cooked,
            '(class=["''])ai-artifact(["''])',
            '\1web-artifact\2',
            'g'
          ),
          'data-ai-artifact-(id|version|height|autorun|seamless)',
          'data-web-artifact-\1',
          'g'
        ),
      baked_version = NULL
    FROM cte
    WHERE posts.id = cte.id
  SQL

  def up
    sql = UPDATE_SQL % { where_clause: WHERE_CLAUSE }
    loop do
      count = DB.exec(sql, batch_size: BATCH_SIZE)
      break if count == 0
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
