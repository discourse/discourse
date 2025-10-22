# frozen_string_literal: true

class UpdateAutomationScriptModels < ActiveRecord::Migration[7.0]
  def up
    script_names = %w[llm_triage llm_report]

    fields_to_update = DB.query(<<~SQL, script_names: script_names)
      SELECT fields.id, fields.metadata
      FROM discourse_automation_fields fields
      INNER JOIN discourse_automation_automations automations ON automations.id = fields.automation_id
      WHERE fields.name = 'model'
      AND automations.script IN (:script_names)
    SQL

    return if fields_to_update.empty?

    updated_fields =
      fields_to_update
        .map do |field|
          new_metadata = { "value" => translate_model(field.metadata["value"]) }.to_json

          "(#{field.id}, '#{new_metadata}')" if new_metadata.present?
        end
        .compact

    return if updated_fields.empty?

    DB.exec(<<~SQL)
      UPDATE discourse_automation_fields AS fields
      SET metadata = new_fields.metadata::jsonb
      FROM (VALUES #{updated_fields.join(", ")}) AS new_fields(id, metadata)
      WHERE new_fields.id::bigint = fields.id
    SQL
  end

  def translate_model(current_model)
    options = DB.query(<<~SQL, name: current_model.to_s).to_a
      SELECT id, provider
      FROM llm_models
      WHERE name = :name
    SQL

    return if options.empty?
    return "custom:#{options.first.id}" if options.length == 1

    priority_provider = options.find { |o| o.provider == "aws_bedrock" || o.provider == "vllm" }

    return "custom:#{priority_provider.id}" if priority_provider

    "custom:#{options.first.id}"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
