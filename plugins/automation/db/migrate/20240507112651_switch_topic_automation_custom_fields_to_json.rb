# frozen_string_literal: true

class SwitchTopicAutomationCustomFieldsToJson < ActiveRecord::Migration[7.0]
  def up
    results = DB.query(<<~SQL)
      SELECT topic_id, ARRAY_AGG(value) AS values
      FROM topic_custom_fields
      WHERE name = 'discourse_automation_ids'
      GROUP BY topic_id
    SQL

    execute(<<~SQL)
      DELETE FROM topic_custom_fields
      WHERE name = 'discourse_automation_ids'
    SQL

    results.each do |row|
      parsed = row.values.map(&:to_i).uniq

      DB.exec(<<~SQL, topic_id: row.topic_id, value: parsed.to_json)
        INSERT INTO topic_custom_fields
        (topic_id, name, value, created_at, updated_at)
        VALUES
        (:topic_id, 'discourse_automation_ids_json', :value, NOW(), NOW())
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
