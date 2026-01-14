# frozen_string_literal: true
class CopyAiSummarizationModelToPersonaDefault < ActiveRecord::Migration[7.2]
  def up
    ai_summarization_model =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'ai_summarization_model'").first

    if ai_summarization_model.present? && ai_summarization_model.start_with?("custom:")
      # Extract the model ID from the setting value (e.g., "custom:-5" -> "-5")
      model_id = ai_summarization_model.split(":").last

      persona_settings = %w[ai_summarization_persona ai_summary_gists_persona]
      default_persona_ids = [-11, -12]

      persona_ids_query =
        persona_settings
          .map { |setting| "SELECT value FROM site_settings WHERE name = '#{setting}'" }
          .join(" UNION ")
      persona_ids = DB.query_single(persona_ids_query).compact
      all_persona_ids = (default_persona_ids + persona_ids).map(&:to_i).uniq.join(",")

      # Update the summarization personas with the extracted model ID
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
