# frozen_string_literal: true

class DropToolDetailsFromAiPersonas < ActiveRecord::Migration[8.0]
  def up
    Migration::ColumnDropper.execute_drop(:ai_personas, %i[tool_details])
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
