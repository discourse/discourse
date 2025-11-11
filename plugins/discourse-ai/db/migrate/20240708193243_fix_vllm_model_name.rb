# frozen_string_literal: true
class FixVllmModelName < ActiveRecord::Migration[7.1]
  def up
    vllm_mixtral_model_id = DB.query_single(<<~SQL).first
      SELECT id FROM llm_models WHERE name = 'mistralai/Mixtral'
    SQL

    DB.exec(<<~SQL, target_id: vllm_mixtral_model_id) if vllm_mixtral_model_id
      UPDATE llm_models
      SET name = 'mistralai/Mixtral-8x7B-Instruct-v0.1'
      WHERE id = :target_id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
