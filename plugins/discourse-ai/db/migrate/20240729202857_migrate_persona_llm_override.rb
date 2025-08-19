# frozen_string_literal: true
class MigratePersonaLlmOverride < ActiveRecord::Migration[7.1]
  def up
    fields_to_update = DB.query(<<~SQL)
      SELECT id, default_llm
      FROM ai_personas
      WHERE default_llm IS NOT NULL
    SQL

    return if fields_to_update.empty?

    updated_fields =
      fields_to_update
        .map do |field|
          llm_model_id = matching_llm_model(field.default_llm)

          "(#{field.id}, 'custom:#{llm_model_id}')" if llm_model_id
        end
        .compact

    return if updated_fields.empty?

    DB.exec(<<~SQL)
      UPDATE ai_personas
      SET default_llm = new_fields.new_default_llm
      FROM (VALUES #{updated_fields.join(", ")}) AS new_fields(id, new_default_llm)
      WHERE new_fields.id::bigint = ai_personas.id
    SQL
  end

  def matching_llm_model(model)
    provider = model.split(":").first
    model_name = model.split(":").last

    return if provider == "custom"

    DB.query_single(
      "SELECT id FROM llm_models WHERE name = :name AND provider = :provider",
      { name: model_name, provider: provider },
    ).first
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
