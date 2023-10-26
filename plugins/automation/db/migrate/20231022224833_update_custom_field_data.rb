# frozen_string_literal: true

class UpdateCustomFieldData < ActiveRecord::Migration[7.0]
  def up
    DB.exec(<<~SQL)
      UPDATE discourse_automation_fields daf
      SET metadata = CONCAT('{"value":', REPLACE(daf.metadata ->> 'value', 'user_field_', ''), '}')::JSONB,
          component = 'custom_field'
      FROM discourse_automation_automations daa
      WHERE daa.id = daf.automation_id
        AND daa.trigger = 'recurring'
        AND daa.script = 'add_user_to_group_through_custom_field'
        AND daf.name = 'custom_field_name'
        AND daf.component = 'text'
        AND daf.metadata ->>'value' LIKE 'user_field_%'
    SQL

    DB.exec(<<~SQL)
      UPDATE discourse_automation_fields daf
      SET metadata = CONCAT('{"value":', (SELECT id FROM user_fields WHERE name = daf.metadata ->> 'value'), '}')::JSONB,
          component = 'custom_field'
      FROM discourse_automation_automations daa
      WHERE daa.id = daf.automation_id
        AND daa.trigger = 'user_first_logged_in'
        AND daa.script = 'add_user_to_group_through_custom_field'
        AND daf.component = 'text'
        AND daf.name = 'custom_field_name'
    SQL
  end

  def down
    DB.exec(<<~SQL)
      UPDATE discourse_automation_fields daf
      SET metadata = CONCAT('{"value": "user_field_', daf.metadata ->> 'value', '"}')::JSONB,
          component = 'text'
      FROM discourse_automation_automations daa
      WHERE daa.id = daf.automation_id
      AND daa.trigger = 'recurring'
      AND daa.script = 'add_user_to_group_through_custom_field'
      AND daf.component = 'custom_field'
      AND daf.name = 'custom_field_name'
    SQL

    DB.exec(<<~SQL)
      UPDATE discourse_automation_fields daf
      SET metadata = CONCAT('{"value": "', (SELECT name FROM user_fields WHERE id = (daf.metadata ->> 'value')::INTEGER), '"}')::JSONB,
          component = 'text'
      FROM discourse_automation_automations daa
      WHERE daa.id = daf.automation_id
        AND daa.trigger = 'user_first_logged_in'
        AND daa.script = 'add_user_to_group_through_custom_field'
        AND daf.component = 'custom_field'
        AND daf.name = 'custom_field_name'
    SQL
  end
end
