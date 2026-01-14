# frozen_string_literal: true
class CopyHydeModelToPersona < ActiveRecord::Migration[7.2]
  def up
    hyde_model =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'ai_embeddings_semantic_search_hyde_model'",
      ).first

    if hyde_model.present? && hyde_model.start_with?("custom:")
      # Extract the model ID from the setting value (e.g., "custom:1" -> "1")
      model_id = hyde_model.split(":").last

      persona_settings = %w[ai_embeddings_semantic_search_hyde_persona]
      default_persona_ids = [-32]
      persona_ids_query =
        persona_settings
          .map { |setting| "SELECT value FROM site_settings WHERE name = '#{setting}'" }
          .join(" UNION ")
      persona_ids = DB.query_single(persona_ids_query).compact

      all_persona_ids = (default_persona_ids + persona_ids).map(&:to_i).uniq.join(",")

      # Update the hyde persona with the extracted model ID
      execute(<<~SQL)
        UPDATE ai_personas
        SET default_llm_id = #{model_id}
        WHERE id IN (#{all_persona_ids}) AND default_llm_id IS NULL
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
