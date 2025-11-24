# frozen_string_literal: true

class BackfillLlmIdOnAiApiRequestStats < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    return unless table_exists?(:ai_api_request_stats)
    return unless table_exists?(:llm_models)

    # Best effort backfill: match language_model to llm_models.name
    # When multiple models share the same name, use the one with the lowest id
    execute <<~SQL
      UPDATE ai_api_request_stats
      SET llm_id = matched.llm_id
      FROM (
        SELECT DISTINCT ON (language_model) name AS language_model, id AS llm_id
        FROM llm_models
        ORDER BY language_model, id
      ) matched
      WHERE ai_api_request_stats.llm_id IS NULL
        AND ai_api_request_stats.language_model = matched.language_model
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
