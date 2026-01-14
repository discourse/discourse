# frozen_string_literal: true

class SeedPersonasFromTriageScripts < ActiveRecord::Migration[8.0]
  def up
    script_fields = DB.query <<~SQL
      SELECT fields.id, fields.name, (fields.metadata->>'value') AS value, automations.name AS automation_name, automations.id AS automation_id
      FROM discourse_automation_fields fields
      INNER JOIN discourse_automation_automations automations ON automations.id = fields.automation_id
      WHERE fields.name IN ('model', 'system_prompt', 'temperature')
      AND automations.script = 'llm_triage'
    SQL

    return if script_fields.empty?

    script_fields =
      script_fields.reduce({}) do |acc, field|
        id = field.automation_id
        acc[id] = { "automation_id" => id, "name" => field.automation_name } if acc[id].nil?

        acc[field.automation_id].merge!(field.name => field.value)

        acc
      end

    automation_to_persona_ids =
      script_fields.transform_values do |field|
        if field["system_prompt"].blank?
          nil
        else
          name =
            (
              if field["name"].present?
                "#{field["name"]} triage automation"
              else
                "Unnamed triage automation script ID #{field["automation_id"]}"
              end
            )

          # Persona's name field cannot be longer than 100 chars.
          name = name.truncate(99)

          temp = field["temperature"]

          # Extract the model ID from the setting value (e.g., "custom:-5" -> "-5")
          model = field["model"]
          model = model.split(":").last if model && model.start_with?("custom:")

          desc = "Seeded Persona for an LLM Triage script"
          prompt = field["system_prompt"]

          existing_id = DB.query_single(<<~SQL, name: name).first
              SELECT id from ai_personas where name = :name
            SQL

          next existing_id if existing_id.present?

          DB.query_single(
            <<~SQL,
            INSERT INTO ai_personas (name, description, enabled, system_prompt, temperature, default_llm_id, created_at, updated_at)
            VALUES (:name, :desc, FALSE, :prompt, :temp, :model, NOW(), NOW())
            RETURNING id
          SQL
            name: name,
            desc: desc,
            prompt: prompt,
            temp: temp,
            model: model,
          )&.first
        end
      end

    new_fields =
      automation_to_persona_ids
        .map do |k, v|
          if v.blank?
            nil
          else
            "(#{k}, 'triage_persona', json_build_object('value', #{v}), 'choices', 'script', NOW(), NOW())"
          end
        end
        .compact

    return if new_fields.empty?

    DB.exec <<~SQL
      INSERT INTO discourse_automation_fields (automation_id, name, metadata, component, target, created_at, updated_at)
      VALUES #{new_fields.join(",")}
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
