# frozen_string_literal: true

class RenameCorePrefixToFlow < ActiveRecord::Migration[7.2]
  def up
    # Update node type identifiers in workflow node definitions (JSONB)
    DB.exec(<<~SQL)
      UPDATE discourse_workflows_workflows
      SET nodes = (
        SELECT jsonb_agg(
          CASE
            WHEN elem->>'type' LIKE 'core:%'
            THEN jsonb_set(elem, '{type}', to_jsonb('flow' || substring(elem->>'type' FROM 5)))
            ELSE elem
          END
        )
        FROM jsonb_array_elements(nodes) AS elem
      )
      WHERE EXISTS (
        SELECT 1 FROM jsonb_array_elements(nodes) AS elem
        WHERE elem->>'type' LIKE 'core:%'
      )
    SQL
  end

  def down
    DB.exec(<<~SQL)
      UPDATE discourse_workflows_workflows
      SET nodes = (
        SELECT jsonb_agg(
          CASE
            WHEN elem->>'type' LIKE 'flow:%'
            THEN jsonb_set(elem, '{type}', to_jsonb('core' || substring(elem->>'type' FROM 5)))
            ELSE elem
          END
        )
        FROM jsonb_array_elements(nodes) AS elem
      )
      WHERE EXISTS (
        SELECT 1 FROM jsonb_array_elements(nodes) AS elem
        WHERE elem->>'type' LIKE 'flow:%'
      )
    SQL
  end
end
