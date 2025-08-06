# frozen_string_literal: true

class DeleteDuplicatedSeededPrompts < ActiveRecord::Migration[7.0]
  def up
    DB.exec <<~SQL
      DELETE FROM completion_prompts
      WHERE (
        (id = 1 AND name = 'translate') OR
        (id = 2 AND name = 'generate_titles') OR
        (id = 3 AND name = 'proofread')
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
