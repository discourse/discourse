# frozen_string_literal: true

class DeactivateAssignmentsToDeletedTargets < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE assignments
      SET active = false
      FROM posts
      WHERE posts.id = assignments.target_id
        AND assignments.target_type = 'Post'
        AND posts.deleted_at IS NOT NULL
        AND assignments.active = true
    SQL

    execute <<~SQL
      UPDATE assignments
      SET active = false
      FROM topics
      WHERE topics.id = assignments.target_id
        AND assignments.target_type = 'Topic'
        AND topics.deleted_at IS NOT NULL
        AND assignments.active = true
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
