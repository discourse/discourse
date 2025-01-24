# frozen_string_literal: true

class SwitchUserAutomationCustomFieldsToJson < ActiveRecord::Migration[7.0]
  def up
    results = DB.query(<<~SQL)
      SELECT user_id, ARRAY_AGG(value) AS values
      FROM user_custom_fields
      WHERE name = 'discourse_automation_ids'
      GROUP BY user_id
    SQL

    execute(<<~SQL)
      DELETE FROM user_custom_fields
      WHERE name = 'discourse_automation_ids'
    SQL

    results.each do |row|
      parsed = row.values.map(&:to_i).uniq

      DB.exec(<<~SQL, user_id: row.user_id, value: parsed.to_json)
        INSERT INTO user_custom_fields
        (user_id, name, value, created_at, updated_at)
        VALUES
        (:user_id, 'discourse_automation_ids_json', :value, NOW(), NOW())
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
