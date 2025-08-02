# frozen_string_literal: true

class MigrateFieldsFromGroupToGroups < ActiveRecord::Migration[7.1]
  def up
    # correct a previous erroneous migration which was converting `{}` to `{"value": [null]}`
    execute <<-SQL
      UPDATE discourse_automation_fields
      SET
        metadata = '{}'::jsonb
      WHERE
        metadata = '{"value": [null]}'::jsonb
        AND component = 'groups'
        AND name = 'restricted_groups';
    SQL

    execute <<-SQL
      UPDATE discourse_automation_fields
      SET
        component = 'groups',
        name = 'restricted_groups',
        metadata = CASE
                    WHEN metadata != '{}'::jsonb THEN jsonb_set(metadata, '{value}', to_jsonb(ARRAY[(metadata->>'value')::int]))
                    ELSE metadata
                  END
      FROM discourse_automation_automations
      WHERE discourse_automation_fields.automation_id = discourse_automation_automations.id
        AND discourse_automation_automations.trigger = 'post_created_edited'
        AND discourse_automation_fields.name = 'restricted_group'
        AND discourse_automation_fields.component = 'group';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
