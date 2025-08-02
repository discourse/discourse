# frozen_string_literal: true

class DeleteOrphanPostActions < ActiveRecord::Migration[6.0]
  def up
    sql = <<~SQL
      DELETE FROM post_actions
      USING post_actions pa
      LEFT JOIN posts ON posts.id = pa.post_id
      WHERE posts.id IS NULL
      AND post_actions.id = pa.id
    SQL

    execute(sql)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
