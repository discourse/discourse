# frozen_string_literal: true
class RenamePostAutomationFields < ActiveRecord::Migration[7.2]
  def up
    # Rename restricted_groups to restricted_inbox_groups
    execute <<~SQL
      UPDATE discourse_automation_fields
      SET name = 'restricted_inbox_groups'
      WHERE name = 'restricted_groups'
      AND target = 'trigger'
      AND component = 'groups'
      AND automation_id IN (
        SELECT id FROM discourse_automation_automations
        WHERE trigger = 'post_created_edited'
      )
    SQL

    # Migrate restricted_user_group (single group) to restricted_groups (array of groups)
    execute <<~SQL
      INSERT INTO discourse_automation_fields (
        automation_id, component, name, target, metadata, created_at, updated_at
      )
      SELECT
        f.automation_id,
        'groups' as component,
        'restricted_groups' as name,
        f.target,
        jsonb_build_object('value', ARRAY[CAST(f.metadata->>'value' AS INTEGER)]) as metadata,
        NOW() as created_at,
        NOW() as updated_at
      FROM discourse_automation_fields f
      JOIN discourse_automation_automations a ON a.id = f.automation_id
      WHERE f.component = 'group'
      AND f.name = 'restricted_user_group'
      AND f.target = 'trigger'
      AND f.metadata->>'value' IS NOT NULL
      AND a.trigger = 'post_created_edited'
      AND NOT EXISTS (
        SELECT 1 FROM discourse_automation_fields
        WHERE automation_id = f.automation_id
        AND name = 'restricted_groups'
        AND target = 'trigger'
      )
    SQL

    # Handle ignore_group_members boolean + restricted_inbox_groups
    # Copy the restricted_inbox_groups values to excluded_groups when ignore_group_members is true
    execute <<~SQL
      INSERT INTO discourse_automation_fields (
        automation_id, component, name, target, metadata, created_at, updated_at
      )
      SELECT
        i.automation_id,
        'groups' as component,
        'excluded_groups' as name,
        i.target,
        r.metadata,
        NOW() as created_at,
        NOW() as updated_at
      FROM discourse_automation_fields i
      JOIN discourse_automation_fields r ON r.automation_id = i.automation_id
                                        AND r.name = 'restricted_inbox_groups'
                                        AND r.target = 'trigger'
      WHERE i.name = 'ignore_group_members'
      AND i.target = 'trigger'
      AND i.metadata->>'value' = 'true'
      AND i.automation_id IN (
        SELECT id FROM discourse_automation_automations
        WHERE trigger = 'post_created_edited'
      )
      AND NOT EXISTS (
        SELECT 1 FROM discourse_automation_fields
        WHERE automation_id = i.automation_id
        AND name = 'excluded_groups'
        AND target = 'trigger'
      )
    SQL

    # Clean up old fields
    execute <<~SQL
      DELETE FROM discourse_automation_fields
      WHERE name IN ('restricted_user_group', 'ignore_group_members')
      AND target = 'trigger'
      AND automation_id IN (
        SELECT id FROM discourse_automation_automations
        WHERE trigger = 'post_created_edited'
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
