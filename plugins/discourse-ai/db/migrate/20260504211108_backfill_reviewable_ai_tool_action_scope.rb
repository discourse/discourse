# frozen_string_literal: true

class BackfillReviewableAiToolActionScope < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE reviewables r
      SET topic_id = p.topic_id,
          category_id = t.category_id
      FROM ai_tool_actions a
      JOIN posts p ON p.id = a.post_id
      JOIN topics t ON t.id = p.topic_id
      WHERE r.type = 'ReviewableAiToolAction'
        AND r.target_type = 'AiToolAction'
        AND r.target_id = a.id
        AND r.topic_id IS NULL
        AND a.post_id IS NOT NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
