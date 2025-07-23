# frozen_string_literal: true
class MigratePersonaToLlmModelId < ActiveRecord::Migration[7.2]
  def up
    add_column :ai_personas, :default_llm_id, :bigint
    add_column :ai_personas, :question_consolidator_llm_id, :bigint
    # personas are seeded, we do not mark stuff as readonline

    execute <<~SQL
      UPDATE ai_personas
        set
          default_llm_id = (select id from llm_models where ('custom:' || id) = default_llm),
          question_consolidator_llm_id = (select id from llm_models where ('custom:' || id) = question_consolidator_llm)
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
