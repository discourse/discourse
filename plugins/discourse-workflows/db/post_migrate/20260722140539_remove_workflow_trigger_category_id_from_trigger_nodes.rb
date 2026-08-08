# frozen_string_literal: true

class RemoveWorkflowTriggerCategoryIdFromTriggerNodes < ActiveRecord::Migration[8.0]
  TRIGGER_TYPES = <<~SQL.squish
    ('trigger:topic_created', 'trigger:post_created', 'trigger:post_edited',
     'trigger:post_moved', 'trigger:topic_closed', 'trigger:topic_tag_changed',
     'trigger:stale_topic')
  SQL

  def up
    migrate_node_arrays("discourse_workflows_workflows", "nodes")
    migrate_node_arrays("discourse_workflows_workflow_versions", "nodes")
    migrate_snapshot_nodes("discourse_workflows_execution_data", "workflow_data")
    migrate_snapshot_nodes("discourse_workflows_webhooks", "workflow_snapshot")
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
      WHEN #{node_needs_migration_sql("nodes.node", node_parameters_sql)} THEN
        nodes.node || jsonb_build_object(
          'parameters',
          (#{node_parameters_sql} - 'category_id')
            || #{copied_category_ids_sql(node_parameters_sql)}
        )
      ELSE nodes.node
      END
    SQL
  end

  def copied_category_ids_sql(parameters_expression)
    <<~SQL.squish
      CASE
      WHEN COALESCE(jsonb_typeof(#{parameters_expression}->'category_ids'), '') <> 'array'
        AND COALESCE(#{parameters_expression}->>'category_id', '') <> '' THEN
        jsonb_build_object(
          'category_ids',
          jsonb_build_array(#{parameters_expression}->'category_id')
        )
      ELSE '{}'::jsonb
      END
    SQL
  end

  def node_needs_migration_sql(node_expression, parameters_expression)
    <<~SQL.squish
      #{node_expression}->>'type' IN #{TRIGGER_TYPES}
        AND (#{parameters_expression} ? 'category_id')
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

  def existing_node_parameters_sql
    <<~SQL.squish
      CASE
      WHEN jsonb_typeof(existing_nodes.node->'parameters') = 'object' THEN existing_nodes.node->'parameters'
      ELSE '{}'::jsonb
      END
    SQL
  end

  def nodes_need_migration_sql(nodes_expression)
    <<~SQL.squish
      EXISTS (
        SELECT 1
        FROM jsonb_array_elements(#{nodes_expression}) AS existing_nodes(node)
        WHERE #{node_needs_migration_sql("existing_nodes.node", existing_node_parameters_sql)}
      )
    SQL
  end
end
