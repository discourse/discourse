# frozen_string_literal: true

class DropToolDetailsFromAiPersonas < ActiveRecord::Migration[8.0]
  def up
    view_name = table_exists?(:ai_agents) ? :ai_personas : :ai_agents
    table_name = table_exists?(:ai_agents) ? :ai_agents : :ai_personas

    view_existed = connection.view_exists?(view_name)
    execute "DROP VIEW IF EXISTS #{view_name}" if view_existed

    Migration::ColumnDropper.execute_drop(table_name, %i[tool_details])

    execute "CREATE VIEW #{view_name} AS SELECT * FROM #{table_name}" if view_existed
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
