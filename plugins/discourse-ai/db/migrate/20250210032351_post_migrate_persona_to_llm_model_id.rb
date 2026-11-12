# frozen_string_literal: true
class PostMigratePersonaToLlmModelId < ActiveRecord::Migration[7.2]
  def up
    view_existed = connection.view_exists?(:ai_agents)
    execute "DROP VIEW IF EXISTS ai_agents" if view_existed

    remove_column :ai_personas, :default_llm
    remove_column :ai_personas, :question_consolidator_llm

    if view_existed
      columns = connection.columns(:ai_personas).map(&:name).join(", ")
      execute "CREATE VIEW ai_agents AS SELECT #{columns} FROM ai_personas"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
