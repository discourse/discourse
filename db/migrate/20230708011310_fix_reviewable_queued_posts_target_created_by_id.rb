# frozen_string_literal: true

class FixReviewableQueuedPostsTargetCreatedById < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE reviewables
      SET target_created_by_id = created_by_id,
          created_by_id = #{Discourse::SYSTEM_USER_ID}
      WHERE type = 'ReviewableQueuedPost' AND target_created_by_id IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
