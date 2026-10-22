# frozen_string_literal: true

class AddCaseInsensitiveNameIndexToDiscourseWorkflowsDataTables < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      DO $$
      DECLARE
        duplicate RECORD;
        suffix BIGINT;
        candidate TEXT;
      BEGIN
        FOR duplicate IN
          SELECT id, name FROM (
            SELECT id, name, ROW_NUMBER() OVER (PARTITION BY LOWER(name) ORDER BY id) AS position
            FROM discourse_workflows_data_tables
          ) AS ranked
          WHERE position > 1
          ORDER BY id
        LOOP
          suffix := duplicate.id;

          LOOP
            candidate := LEFT(duplicate.name, 100 - LENGTH(suffix::text) - 1) || '_' || suffix;
            EXIT WHEN NOT EXISTS (
              SELECT 1 FROM discourse_workflows_data_tables WHERE LOWER(name) = LOWER(candidate)
            );
            suffix := suffix + 1;
          END LOOP;

          UPDATE discourse_workflows_data_tables SET name = candidate WHERE id = duplicate.id;
        END LOOP;
      END $$;
    SQL

    remove_index :discourse_workflows_data_tables, name: "idx_dwf_data_tables_on_name"
    add_index :discourse_workflows_data_tables,
              "LOWER(name)",
              unique: true,
              name: "idx_dwf_data_tables_on_lower_name"
  end

  def down
    remove_index :discourse_workflows_data_tables, name: "idx_dwf_data_tables_on_lower_name"
    add_index :discourse_workflows_data_tables,
              :name,
              unique: true,
              name: "idx_dwf_data_tables_on_name"
  end
end
