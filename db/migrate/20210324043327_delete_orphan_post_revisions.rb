# frozen_string_literal: true

class DeleteOrphanPostRevisions < ActiveRecord::Migration[6.0]
  def up
    sql = <<~SQL
        DELETE FROM post_revisions
        USING post_revisions pr
        LEFT JOIN posts ON posts.id = pr.post_id
        WHERE posts.id IS NULL
        AND post_revisions.id = pr.id
    SQL

    execute(sql)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
