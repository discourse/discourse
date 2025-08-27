# frozen_string_literal: true
class PostMigratePersonaToLlmModelId < ActiveRecord::Migration[7.2]
  def up
    remove_column :ai_personas, :default_llm
    remove_column :ai_personas, :question_consolidator_llm
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
