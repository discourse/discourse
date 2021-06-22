# frozen_string_literal: true

class BackfillEmailLogTopicId < ActiveRecord::Migration[6.1]
  def up
    DB.exec(<<~SQL)
      UPDATE email_logs AS el
      SET topic_id = t.id
      FROM posts AS p
      INNER JOIN topics t ON t.id = p.topic_id
      WHERE el.post_id = p.id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
