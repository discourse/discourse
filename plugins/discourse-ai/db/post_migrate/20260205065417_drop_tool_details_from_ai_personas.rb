# frozen_string_literal: true

class DropToolDetailsFromAiPersonas < ActiveRecord::Migration[8.0]
  def up
    view_existed = connection.view_exists?(:ai_agents)
    execute "DROP VIEW IF EXISTS ai_agents" if view_existed

    Migration::ColumnDropper.execute_drop(:ai_personas, %i[tool_details])

    if view_existed
      columns = connection.columns(:ai_personas).map(&:name).join(", ")
      execute "CREATE VIEW ai_agents AS SELECT #{columns} FROM ai_personas"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
