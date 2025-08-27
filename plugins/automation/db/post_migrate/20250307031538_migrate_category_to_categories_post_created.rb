# frozen_string_literal: true
class MigrateCategoryToCategoriesPostCreated < ActiveRecord::Migration[7.2]
  def up
    # this is a safety net, should never happen but we don't want dupes here
    execute <<~SQL
      DELETE FROM discourse_automation_fields
      WHERE name = 'restricted_categories'
        AND target = 'trigger'
        AND automation_id IN (
          SELECT id FROM discourse_automation_automations
          WHERE trigger = 'post_created_edited'
        )
    SQL

    execute <<~SQL
      INSERT INTO discourse_automation_fields (
        automation_id, component, name, target, metadata, created_at, updated_at
      )
      SELECT
        f.automation_id,
        'categories' as component,
        'restricted_categories' as name,
        f.target,
        jsonb_build_object('value', ARRAY[CAST(f.metadata->>'value' AS INTEGER)]) as metadata,
        NOW() as created_at,
        NOW() as updated_at
      FROM discourse_automation_fields f
      JOIN discourse_automation_automations a ON a.id = f.automation_id
      WHERE f.component = 'category'
      AND f.name = 'restricted_category'
      AND f.target = 'trigger'
      AND f.metadata->>'value' IS NOT NULL
      AND a.trigger = 'post_created_edited'
    SQL
  end
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
