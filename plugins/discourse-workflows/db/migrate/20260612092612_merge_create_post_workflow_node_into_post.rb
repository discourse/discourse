# frozen_string_literal: true

class MergeCreatePostWorkflowNodeIntoPost < ActiveRecord::Migration[8.0]
  def up
    migrate_node_arrays("discourse_workflows_workflows", "nodes")
    migrate_node_arrays("discourse_workflows_workflow_versions", "nodes")
    migrate_snapshot_nodes("discourse_workflows_execution_data", "workflow_data")
    migrate_snapshot_nodes("discourse_workflows_webhooks", "workflow_snapshot")

    execute <<~SQL
      UPDATE discourse_workflows_workflow_dependencies
      SET dependency_key = 'action:post'
      WHERE dependency_type = 'node_type'
        AND dependency_key = 'action:create_post'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def migrate_node_arrays(table_name, column_name)
    execute <<~SQL
      UPDATE #{table_name}
      SET #{column_name} = (
        SELECT COALESCE(
          jsonb_agg(#{transformed_node_sql} ORDER BY nodes.ordinality),
          '[]'::jsonb
        )
        FROM jsonb_array_elements(#{table_name}.#{column_name}) WITH ORDINALITY AS nodes(node, ordinality)
      )
      WHERE jsonb_typeof(#{column_name}) = 'array'
        AND #{nodes_need_migration_sql(column_name)}
    SQL
  end

  def migrate_snapshot_nodes(table_name, column_name)
    execute <<~SQL
      UPDATE #{table_name}
      SET #{column_name} = jsonb_set(
        #{column_name},
        '{nodes}',
        (
          SELECT COALESCE(
            jsonb_agg(#{transformed_node_sql} ORDER BY nodes.ordinality),
            '[]'::jsonb
          )
          FROM jsonb_array_elements(#{table_name}.#{column_name}->'nodes') WITH ORDINALITY AS nodes(node, ordinality)
        ),
        false
      )
      WHERE jsonb_typeof(#{column_name}->'nodes') = 'array'
        AND #{nodes_need_migration_sql("#{column_name}->'nodes'")}
    SQL
  end

  def transformed_node_sql
    <<~SQL.squish
      CASE
      WHEN nodes.node->>'type' = 'action:create_post' THEN
        nodes.node || jsonb_build_object(
          'type', 'action:post',
          'parameters', #{node_parameters_sql} || jsonb_build_object('operation', 'create')
        )
      WHEN nodes.node->>'type' = 'action:post'
        AND NOT (#{node_parameters_sql} ? 'operation') THEN
        nodes.node || jsonb_build_object(
          'parameters', #{node_parameters_sql} || jsonb_build_object('operation', 'list')
        )
      ELSE nodes.node
      END
    SQL
  end

  def node_parameters_sql
    <<~SQL.squish
      CASE
      WHEN jsonb_typeof(nodes.node->'parameters') = 'object' THEN nodes.node->'parameters'
      ELSE '{}'::jsonb
      END
    SQL
  end

  def nodes_need_migration_sql(nodes_expression)
    <<~SQL.squish
      EXISTS (
        SELECT 1
        FROM jsonb_array_elements(#{nodes_expression}) AS existing_nodes(node)
        WHERE existing_nodes.node->>'type' = 'action:create_post'
          OR (
            existing_nodes.node->>'type' = 'action:post'
            AND NOT (
              CASE
              WHEN jsonb_typeof(existing_nodes.node->'parameters') = 'object' THEN existing_nodes.node->'parameters'
              ELSE '{}'::jsonb
              END ? 'operation'
            )
          )
      )
    SQL
  end
end
