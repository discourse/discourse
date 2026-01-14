# frozen_string_literal: true
class ReportRunnerModelFieldCleanup < ActiveRecord::Migration[8.0]
  def up
    models_to_update = DB.query(<<~SQL)
      SELECT fields.id, fields.metadata
      FROM discourse_automation_fields fields
      INNER JOIN discourse_automation_automations automations ON automations.id = fields.automation_id
      WHERE fields.name = 'model'
      AND automations.script = 'llm_report'
    SQL

    models_to_update =
      models_to_update
        .map do |model|
          current_model = model.metadata&.dig("value")
          next nil if current_model.blank? || !current_model.to_s.start_with?("custom:")

          "(#{model.id}, json_build_object('value', #{current_model.split(":").last}))"
        end
        .compact

    return if models_to_update.empty?

    DB.exec(<<~SQL)
      UPDATE discourse_automation_fields AS fields
      SET metadata = new_fields.metadata::jsonb
      FROM (VALUES #{models_to_update.join(",")}) AS new_fields(id, metadata)
      WHERE new_fields.id::bigint = fields.id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
