# frozen_string_literal: true

class MovePrevAssignedCustomFieldsToAssignments < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
        INSERT INTO assignments (assigned_to_id, assigned_to_type, assigned_by_user_id, topic_id, target_id, target_type, created_at, updated_at, active)
        SELECT
          prev_assigned_to_id.value::integer,
          prev_assigned_to_type.value,
          #{Discourse::SYSTEM_USER_ID},
          prev_assigned_to_type.topic_id,
          prev_assigned_to_type.topic_id,
          'Topic',
          prev_assigned_to_type.created_at,
          prev_assigned_to_type.updated_at,
          false
        FROM topic_custom_fields prev_assigned_to_type
        INNER JOIN topic_custom_fields prev_assigned_to_id ON prev_assigned_to_type.topic_id = prev_assigned_to_id.topic_id
        WHERE prev_assigned_to_type.name = 'prev_assigned_to_type'
          AND prev_assigned_to_id.name = 'prev_assigned_to_id'
        ORDER BY prev_assigned_to_type.created_at DESC
        ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
