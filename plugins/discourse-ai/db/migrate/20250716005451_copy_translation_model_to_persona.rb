# frozen_string_literal: true
class CopyTranslationModelToPersona < ActiveRecord::Migration[7.2]
  def up
    ai_translation_model =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'ai_translation_model'").first

    if ai_translation_model.present? && ai_translation_model.start_with?("custom:")
      # Extract the model ID from the setting value (e.g., "custom:-5" -> "-5")
      model_id = ai_translation_model.split(":").last

      persona_settings = %w[
        ai_translation_locale_detector_persona
        ai_translation_post_raw_translator_persona
        ai_translation_topic_title_translator_persona
        ai_translation_short_text_translator_persona
      ]
      default_persona_ids = [-27, -28, -29, -30]

      persona_ids_query =
        persona_settings
          .map { |setting| "SELECT value FROM site_settings WHERE name = '#{setting}'" }
          .join(" UNION ")
      persona_ids = DB.query_single(persona_ids_query).compact

      all_persona_ids = (default_persona_ids + persona_ids).map(&:to_i).uniq.join(",")

      # Update the translation personas (IDs -27, -28, -29, -30) with the extracted model ID
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
