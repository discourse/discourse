# frozen_string_literal: true
class SetCorrectDefaultForShortSummarizerPersona < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE ai_personas
      SET allowed_group_ids = ARRAY[0]
      WHERE id = -12 AND allowed_group_ids = '{}'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
